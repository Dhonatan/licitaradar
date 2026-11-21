class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      # SHA-256 of the token; the token itself is only shown once, when it is created.
      t.string :token_digest, null: false
      # First characters of the token, to recognize it in the list.
      t.string :token_hint, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
  end
end
