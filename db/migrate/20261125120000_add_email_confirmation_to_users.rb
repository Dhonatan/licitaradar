class AddEmailConfirmationToUsers < ActiveRecord::Migration[8.1]
  def change
    # nil until the user opens the link of the confirmation e-mail. Existing accounts start
    # unconfirmed too: nothing proves they own their address (see docs/sprint/LOG.md, day 6).
    add_column :users, :confirmed_at, :datetime
    # The new address of a pending e-mail change; it replaces email_address once confirmed.
    add_column :users, :unconfirmed_email, :string
  end
end
