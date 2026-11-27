# An open tender ("contratação") published on the PNCP. Rows are written in bulk by
# Tenders::Sync (upsert by pncp_control_number); attributes mirror Pncp::TenderNormalizer.
class Tender < ApplicationRecord
  # situacaoCompraId 1 = "Divulgada no PNCP" (published and active).
  PUBLISHED_STATUS_ID = 1

  # Accent folding shared by the `searchable` column (see the FoldAccentsInTendersSearchable
  # migration) and search queries, so "agencia" and "agência" are the same word.
  ACCENTED = "áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ"
  UNACCENTED = "aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN"

  # Documents and items are fetched on demand (Tenders::FetchDetails), not by the sync.
  DETAILS_REQUEST_INTERVAL = 10.minutes

  has_many :notifications, dependent: :delete_all
  has_many :watches, dependent: :delete_all
  has_many :documents, -> { ordered }, class_name: "TenderDocument", inverse_of: :tender, dependent: :delete_all
  has_many :items, -> { ordered }, class_name: "TenderItem", inverse_of: :tender, dependent: :delete_all

  validates :pncp_control_number, presence: true, uniqueness: true
  validates :modality_id, inclusion: { in: Pncp::Modalities::ALL.keys }, allow_nil: true
  validates :state, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true
  validates :estimated_value, :awarded_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :open_for_proposals, -> { where(status_id: PUBLISHED_STATUS_ID).where(arel_table[:proposals_close_at].gt(Time.current)) }
  scope :closing_within, ->(days) { open_for_proposals.where(proposals_close_at: ..days.to_i.days.from_now) }
  scope :in_state, ->(states) {
    states = Array(states).compact_blank.map { |state| state.to_s.upcase }
    where(state: states) if states.any?
  }
  scope :of_modality, ->(ids) {
    ids = Array(ids).compact_blank.map(&:to_i)
    where(modality_id: ids) if ids.any?
  }
  scope :value_between, ->(min, max) {
    min = min.presence
    max = max.presence
    where(estimated_value: min..max) if min || max
  }

  def self.fold_accents(text)
    text.to_s.tr(ACCENTED, UNACCENTED)
  end

  def open_for_proposals?
    status_id == PUBLISHED_STATUS_ID && proposals_close_at.present? && proposals_close_at.future?
  end

  # "open", "closing_today" (still open, closes today in Brasília time), "closed" or
  # "unknown" (published without a deadline). Badges of "Minhas licitações" and the API.
  def proposals_status(now: Time.current)
    published = status_id == PUBLISHED_STATUS_ID
    return "unknown" if published && proposals_close_at.nil?
    return "closed" unless published && proposals_close_at > now

    proposals_close_at.in_time_zone.to_date == now.in_time_zone.to_date ? "closing_today" : "open"
  end

  # The integration API addresses a tender by agency CNPJ, year and sequence.
  def details_fetchable?
    agency_cnpj.to_s.delete("^0-9").length == 14 && year.present? && sequence.present?
  end

  def details_fetched?
    details_fetched_at.present?
  end

  # Never fetched, or the tender changed on the PNCP since the last fetch.
  def details_stale?
    !details_fetched? || details_source_updated_at != source_updated_at
  end

  # Enqueues FetchTenderDetailsJob when the details are stale, at most once per
  # DETAILS_REQUEST_INTERVAL (page views and frame reloads call this freely). The claim is
  # a conditional UPDATE, so concurrent requests enqueue one job. Returns true if enqueued.
  def request_details_fetch
    return false unless details_fetchable? && details_stale?

    now = Time.current
    claimed = Tender.where(id: id)
      .where("details_requested_at IS NULL OR details_requested_at <= ?", now - DETAILS_REQUEST_INTERVAL)
      .update_all(details_requested_at: now)
    return false unless claimed == 1

    self.details_requested_at = now
    clear_attribute_change(:details_requested_at)
    FetchTenderDetailsJob.perform_later(self)
    true
  end

  # PNCP publishes 0 when the estimate is confidential ("orçamento sigiloso").
  def confidential_value?
    estimated_value.nil? || estimated_value.zero?
  end
end
