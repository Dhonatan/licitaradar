# Records that a tender was sent to a user for one of their saved searches, so the same
# tender is never alerted twice for that search (unique index on saved_search + tender).
class Notification < ApplicationRecord
  belongs_to :saved_search
  belongs_to :tender

  validates :sent_at, presence: true
  validates :tender_id, uniqueness: { scope: :saved_search_id }

  # Bulk insert for the digest: tenders already recorded for the search are skipped.
  # Returns how many new rows were written.
  def self.record!(saved_search, tenders, sent_at: Time.current)
    rows = Array(tenders).map { |tender| { saved_search_id: saved_search.id, tender_id: tender.id, sent_at: sent_at } }
    return 0 if rows.empty?

    insert_all(rows, unique_by: %i[ saved_search_id tender_id ]).length
  end
end
