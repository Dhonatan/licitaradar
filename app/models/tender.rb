# An open tender ("contratação") published on the PNCP. Rows are written in bulk by
# Tenders::Sync (upsert by pncp_control_number); attributes mirror Pncp::TenderNormalizer.
class Tender < ApplicationRecord
  # situacaoCompraId 1 = "Divulgada no PNCP" (published and active).
  PUBLISHED_STATUS_ID = 1

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

  def open_for_proposals?
    status_id == PUBLISHED_STATUS_ID && proposals_close_at.present? && proposals_close_at.future?
  end

  # PNCP publishes 0 when the estimate is confidential ("orçamento sigiloso").
  def confidential_value?
    estimated_value.nil? || estimated_value.zero?
  end
end
