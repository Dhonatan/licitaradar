# Items of a tender (what is being bought, quantities and estimated values) as listed by
# the PNCP integration API. Rows go away with their tender.
class CreateTenderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :tender_items do |t|
      t.references :tender, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.integer :number, null: false
      t.text :description
      t.string :material_or_service
      t.decimal :quantity, precision: 18, scale: 4
      t.string :unit
      # nil when the budget is confidential ("orçamento sigiloso").
      t.decimal :unit_estimated_value, precision: 18, scale: 4
      t.decimal :total_estimated_value, precision: 18, scale: 4
      t.boolean :confidential_budget, null: false, default: false
      t.string :status_name
      t.string :judgment_criterion_name
      t.string :benefit_name
      t.string :category_name
      t.datetime :source_updated_at

      t.timestamps
    end
    add_index :tender_items, %i[ tender_id number ], unique: true
  end
end
