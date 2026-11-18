class CreateTenders < ActiveRecord::Migration[8.1]
  def change
    create_table :tenders do |t|
      # Identification (numeroControlePNCP is the PNCP's own unique key).
      t.string :pncp_control_number, null: false
      t.integer :year
      t.integer :sequence
      t.string :purchase_number
      t.string :process_number

      # Modality and status.
      t.integer :modality_id
      t.string :modality_name
      t.string :dispute_mode_name
      t.integer :status_id
      t.string :status_name

      # What is being bought.
      t.text :object_description
      t.text :additional_info
      t.boolean :price_registration, null: false, default: false
      t.decimal :estimated_value, precision: 15, scale: 4
      t.decimal :awarded_value, precision: 15, scale: 4

      # Dates (stored in UTC, published by the PNCP in Brasília time).
      t.datetime :proposals_open_at
      t.datetime :proposals_close_at
      t.datetime :published_at
      t.datetime :source_updated_at

      # Buying agency and unit.
      t.string :agency_cnpj
      t.string :agency_name
      t.string :agency_power
      t.string :agency_sphere
      t.string :unit_code
      t.string :unit_name
      t.string :ibge_code
      t.string :city
      t.string :state

      # Links.
      t.string :origin_url
      t.string :pncp_url

      # Original API record (CPFs masked) and sync bookkeeping.
      t.jsonb :raw, null: false, default: {}
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :tenders, :pncp_control_number, unique: true
    add_index :tenders, :proposals_close_at
    add_index :tenders, :state
    add_index :tenders, :modality_id
    add_index :tenders, :status_id
  end
end
