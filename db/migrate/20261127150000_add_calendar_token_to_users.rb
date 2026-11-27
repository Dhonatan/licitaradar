# Secret token of the user's iCalendar feed (/calendario/:token.ics) with the deadlines of
# the watched tenders. Calendar apps cannot send credentials, so the URL is the secret.
class AddCalendarTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :calendar_token, :string
    add_index :users, :calendar_token, unique: true
  end
end
