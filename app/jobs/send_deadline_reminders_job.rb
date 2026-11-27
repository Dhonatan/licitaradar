# E-mails every confirmed user with deadline reminders on (User#deadline_reminder_days)
# the watched tenders whose proposals deadline is near (see Watches::DeadlineReminder).
# Scheduled every morning in config/recurring.yml; running it again sends nothing new.
class SendDeadlineRemindersJob < ApplicationJob
  queue_as :default

  # Returns { users:, sent:, failed: }.
  def perform
    stats = { users: 0, sent: 0, failed: 0 }

    User.with_deadline_reminders.find_each do |user|
      stats[:users] += 1
      stats[:sent] += 1 if Watches::DeadlineReminder.new(user).deliver
    rescue StandardError => error
      # One bad address or record must not stop everybody else's reminders.
      stats[:failed] += 1
      Rails.error.report(error, handled: true, context: { user_id: user.id })
    end

    logger.info "Deadline reminders: #{stats[:sent]} sent, #{stats[:failed]} failed, #{stats[:users]} users checked"
    stats
  end
end
