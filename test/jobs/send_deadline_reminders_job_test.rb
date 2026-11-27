require "test_helper"

class SendDeadlineRemindersJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @ana = create_user(email_address: "ana@example.com")
    @bia = create_user(email_address: "bia@example.com")
    @soon = create_open_tender(object_description: "Serviço de buffet", proposals_close_at: 2.days.from_now)
    @later = create_open_tender(object_description: "Locação de palco", proposals_close_at: 20.days.from_now)
    Watch.watch!(@ana, @soon)
    Watch.watch!(@bia, @soon)
    Watch.watch!(@bia, @later)
    Watch.watch!(create_user(email_address: "nao-confirmada@example.com", confirmed: false), @soon)
    Watch.watch!(create_user(email_address: "desligado@example.com").tap { |user| user.update!(deadline_reminder_days: 0) }, @soon)
    Watch.watch!(create_user(email_address: "longe@example.com"), @later)
  end

  test "e-mails the confirmed users with reminders on whose watched deadlines are near" do
    stats = nil
    assert_emails 2 do
      stats = SendDeadlineRemindersJob.perform_now
    end

    assert_equal({ users: 3, sent: 2, failed: 0 }, stats)
    assert_equal %w[ ana@example.com bia@example.com ], ActionMailer::Base.deliveries.flat_map(&:to).sort
    assert_equal 2, Watch.where.not(reminded_close_at: nil).count
  end

  test "a second run sends nothing" do
    SendDeadlineRemindersJob.perform_now

    assert_no_emails do
      assert_equal({ users: 3, sent: 0, failed: 0 }, SendDeadlineRemindersJob.perform_now)
    end
  end

  test "a failing reminder does not stop the others" do
    @ana.update_column(:email_address, "")

    stats = nil
    assert_emails 1 do
      stats = SendDeadlineRemindersJob.perform_now
    end

    assert_equal({ users: 3, sent: 1, failed: 1 }, stats)
    assert_equal [ "bia@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_nil @ana.watches.first.reminded_close_at
  end

  test "is enqueued on the default queue" do
    assert_enqueued_with(job: SendDeadlineRemindersJob, queue: "default") do
      SendDeadlineRemindersJob.perform_later
    end
  end
end
