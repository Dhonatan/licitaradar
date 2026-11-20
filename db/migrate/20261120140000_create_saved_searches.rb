class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :query
      t.jsonb :filters, null: false, default: {}
      t.string :niche_slug
      t.boolean :active, null: false, default: true
      t.boolean :notify_daily, null: false, default: true
      t.datetime :last_notified_at

      t.timestamps
    end
  end
end
