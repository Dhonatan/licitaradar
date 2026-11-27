# Deadline reminders: how many days before the proposals deadline each user wants an
# e-mail about the tenders they watch (0 = off), and which deadline each watch was last
# reminded about, so a reminder is never sent twice for the same deadline but is sent
# again when the PNCP moves it.
class AddDeadlineReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deadline_reminder_days, :integer, null: false, default: 3
    add_column :watches, :reminded_close_at, :datetime
    add_column :watches, :reminded_at, :datetime
  end
end
