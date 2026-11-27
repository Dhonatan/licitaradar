# A user following a tender ("Acompanhar"). Tenders::Archive keeps watched tenders, so the
# cascade on tenders only matters for manual deletions.
class CreateWatches < ActiveRecord::Migration[8.1]
  def change
    create_table :watches do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :tender, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
    add_index :watches, %i[ user_id tender_id ], unique: true
  end
end
