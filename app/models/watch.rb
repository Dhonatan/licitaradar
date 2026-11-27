# A tender a user follows ("Acompanhar"), listed on "Minhas licitações". Tenders::Archive
# keeps every watched tender, however old.
class Watch < ApplicationRecord
  MAX_PER_USER = 500

  belongs_to :user
  belongs_to :tender

  validates :tender_id, uniqueness: { scope: :user_id }
  validate :watches_per_user_limit, on: :create

  # Tenders still open for proposals first (closest deadline first), then the closed ones
  # (most recently closed first), then those without a deadline.
  scope :by_deadline, ->(now = Time.current) {
    open = "tenders.status_id = :status AND tenders.proposals_close_at > :now"
    order_sql = sanitize_sql_array([ <<~SQL.squish, { status: Tender::PUBLISHED_STATUS_ID, now: now } ])
      CASE WHEN #{open} THEN 0 WHEN tenders.proposals_close_at IS NOT NULL THEN 1 ELSE 2 END,
      CASE WHEN #{open} THEN tenders.proposals_close_at END ASC,
      tenders.proposals_close_at DESC,
      watches.id ASC
    SQL
    joins(:tender).order(Arel.sql(order_sql))
  }

  # Watches of tenders still open whose proposals close within `days` calendar days
  # (Brasília time: with 3 days, on Friday morning everything closing until Monday 23:59)
  # and that were not reminded about this deadline yet.
  scope :due_for_reminder, ->(days, now = Time.current) {
    last_day = (now.in_time_zone.to_date + days.to_i).end_of_day
    joins(:tender)
      .where(tenders: { status_id: Tender::PUBLISHED_STATUS_ID })
      .where(Tender.arel_table[:proposals_close_at].gt(now))
      .where(Tender.arel_table[:proposals_close_at].lteq(last_day))
      .where("watches.reminded_close_at IS NULL OR watches.reminded_close_at <> tenders.proposals_close_at")
  }

  # Finds the user's watch of the tender or creates it (safe against double clicks: the
  # unique index decides). Returns the watch, unsaved with errors when the limit is reached.
  def self.watch!(user, tender)
    user.watches.find_by(tender: tender) || user.watches.create(tender: tender)
  rescue ActiveRecord::RecordNotUnique
    user.watches.find_by!(tender: tender)
  end

  private
    def watches_per_user_limit
      return unless user && user.watches.count >= MAX_PER_USER

      errors.add(:base, "Você já acompanha #{MAX_PER_USER} licitações, o máximo por conta. Deixe de acompanhar alguma para seguir esta.")
    end
end
