# When the documents and items of a tender were fetched, which PNCP version of the tender
# they belong to (refetched when `source_updated_at` changes) and when a fetch was last
# requested (so page views do not enqueue a job each).
class AddDetailsTrackingToTenders < ActiveRecord::Migration[8.1]
  def change
    add_column :tenders, :details_fetched_at, :datetime
    add_column :tenders, :details_source_updated_at, :datetime
    add_column :tenders, :details_requested_at, :datetime
  end
end
