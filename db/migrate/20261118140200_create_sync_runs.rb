class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.integer :modality_id, null: false
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :pages, null: false, default: 0
      t.integer :fetched_count, null: false, default: 0
      t.integer :upserted_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :sync_runs, [ :modality_id, :started_at ]
    add_index :sync_runs, :status
  end
end
