class AddAttemptToSyncRuns < ActiveRecord::Migration[8.1]
  def change
    # 1 for the scheduled run, 2.. for the automatic retries of SyncOpenTendersJob.
    add_column :sync_runs, :attempt, :integer, null: false, default: 1
  end
end
