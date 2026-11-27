require "test_helper"

module Watches
  class DeadlineReminderTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @now = Time.zone.parse("2026-11-27 07:30") # a Friday
      @user = create_user(email_address: "ana@example.com")
    end

    def watch(close_at, **attributes)
      Watch.watch!(@user, create_open_tender(proposals_close_at: close_at, published_at: @now - 5.days, **attributes))
    end

    test "lists the watched tenders closing within the user's days, closest first" do
      monday = watch(Time.zone.parse("2026-11-30 23:00"))
      today = watch(Time.zone.parse("2026-11-27 18:00"))
      watch(Time.zone.parse("2026-12-01 09:00"))
      watch(Time.zone.parse("2026-11-27 07:00"))
      watch(Time.zone.parse("2026-11-28 10:00"), status_id: 3)

      assert_equal [ today, monday ], DeadlineReminder.new(@user, now: @now).watches
    end

    test "follows the user's setting" do
      week = watch(Time.zone.parse("2026-12-04 10:00"))

      @user.update!(deadline_reminder_days: 7)
      assert_equal [ week ], DeadlineReminder.new(@user, now: @now).watches

      @user.update!(deadline_reminder_days: 1)
      assert_empty DeadlineReminder.new(@user, now: @now).watches

      @user.update!(deadline_reminder_days: 0)
      watch(Time.zone.parse("2026-11-27 18:00"))
      assert_empty DeadlineReminder.new(@user, now: @now).watches
    end

    test "unconfirmed users get no reminders" do
      @user.update!(confirmed_at: nil)
      watch(Time.zone.parse("2026-11-28 10:00"))

      assert_not DeadlineReminder.new(@user, now: @now).deliver
    end

    test "deliver e-mails the reminder and never twice for the same deadline" do
      due = watch(Time.zone.parse("2026-11-29 10:00"))

      assert_emails(1) { assert DeadlineReminder.new(@user, now: @now).deliver }
      mail = ActionMailer::Base.deliveries.last
      assert_equal [ "ana@example.com" ], mail.to
      assert_equal due.tender.proposals_close_at, due.reload.reminded_close_at
      assert_equal @now, due.reminded_at

      assert_no_emails { assert_not DeadlineReminder.new(@user, now: @now + 1.day).deliver }
    end

    test "a deadline moved by the PNCP is reminded again" do
      due = watch(Time.zone.parse("2026-11-29 10:00"))
      DeadlineReminder.new(@user, now: @now).deliver

      due.tender.update!(proposals_close_at: Time.zone.parse("2026-11-30 15:00"))

      assert_emails(1) { assert DeadlineReminder.new(@user, now: @now + 1.day).deliver }
      assert_equal Time.zone.parse("2026-11-30 15:00"), due.reload.reminded_close_at
    end

    test "nothing is recorded when the e-mail fails" do
      due = watch(Time.zone.parse("2026-11-29 10:00"))
      @user.update_column(:email_address, "")

      assert_raises(StandardError) { DeadlineReminder.new(@user, now: @now).deliver }
      assert_nil due.reload.reminded_close_at
    end
  end
end
