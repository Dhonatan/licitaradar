class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :saved_search, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :tender, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :sent_at, null: false

      t.timestamps
    end
    # One alert per tender and saved search, ever.
    add_index :notifications, %i[ saved_search_id tender_id ], unique: true
  end
end
