module Watches
  # One user's deadline reminder: the watched tenders whose proposals close within the
  # user's `deadline_reminder_days` (see Watch.due_for_reminder), in one e-mail, closest
  # deadline first. Each watch remembers the deadline it was reminded about
  # (`reminded_close_at`): the same deadline is never reminded twice, a deadline moved by
  # the PNCP is reminded again.
  #
  #   reminder = Watches::DeadlineReminder.new(user)
  #   reminder.watches  # => what the e-mail would list
  #   reminder.deliver  # => true when an e-mail was sent
  class DeadlineReminder
    attr_reader :user, :now

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def watches
      return [] unless user.confirmed? && user.deadline_reminders?

      @watches ||= user.watches.due_for_reminder(user.deadline_reminder_days, now)
        .preload(:tender).order("tenders.proposals_close_at ASC, watches.id ASC").to_a
    end

    # Sends with deliver_now (the job already runs in the background) and records the
    # deadlines only after the e-mail left.
    def deliver
      return false if watches.empty?

      ReminderMailer.deadlines(user, watches).deliver_now
      watches.each { |watch| watch.update_columns(reminded_close_at: watch.tender.proposals_close_at, reminded_at: now) }
      true
    end
  end
end
