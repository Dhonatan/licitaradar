# Documents of a tender (edital, termo de referência, anexos...) as listed by the PNCP
# integration API. Rows go away with their tender (archiving deletes tenders in bulk).
class CreateTenderDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :tender_documents do |t|
      t.references :tender, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.integer :sequence, null: false
      t.string :title, null: false
      t.integer :type_id
      t.string :type_name
      t.string :url
      t.datetime :published_at

      t.timestamps
    end
    add_index :tender_documents, %i[ tender_id sequence ], unique: true
  end
end
