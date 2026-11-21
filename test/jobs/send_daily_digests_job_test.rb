require "test_helper"

class SendDailyDigestsJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @ana = create_user(email_address: "ana@example.com")
    @bia = create_user(email_address: "bia@example.com")
    @ana.saved_searches.create!(name: "Buffet", query: "buffet")
    @bia.saved_searches.create!(name: "Palco", query: "palco")
    @bia.saved_searches.create!(name: "Buffet também", query: "buffet")
    create_user(email_address: "sem-alerta@example.com").saved_searches.create!(query: "buffet", notify_daily: false)
    create_user(email_address: "pausada@example.com").saved_searches.create!(query: "buffet", active: false)
    create_user(email_address: "sem-buscas@example.com")
  end

  test "sends one e-mail per user with news, only for active searches with daily alerts" do
    create_open_tender(object_description: "Serviço de buffet")
    create_open_tender(object_description: "Locação de palco")

    stats = nil
    assert_emails 2 do
      stats = SendDailyDigestsJob.perform_now
    end

    assert_equal({ users: 2, sent: 2, failed: 0 }, stats)
    assert_equal %w[ ana@example.com bia@example.com ], ActionMailer::Base.deliveries.flat_map(&:to).sort
    bia_mail = ActionMailer::Base.deliveries.find { |mail| mail.to == [ "bia@example.com" ] }
    assert_equal "2 novas licitações abertas para as suas buscas", bia_mail.subject
    assert_equal 3, Notification.count
  end

  test "users without news get no e-mail and a second run sends nothing new" do
    create_open_tender(object_description: "Locação de palco")

    assert_emails 1 do
      SendDailyDigestsJob.perform_now
    end
    assert_no_emails do
      assert_equal({ users: 2, sent: 0, failed: 0 }, SendDailyDigestsJob.perform_now)
    end

    create_open_tender(object_description: "Serviço de buffet")

    assert_emails 2 do
      SendDailyDigestsJob.perform_now
    end
  end

  test "a failing digest does not stop the others" do
    create_open_tender(object_description: "Serviço de buffet")
    @ana.update_column(:email_address, "")

    stats = nil
    assert_emails 1 do
      stats = SendDailyDigestsJob.perform_now
    end

    assert_equal({ users: 2, sent: 1, failed: 1 }, stats)
    assert_equal [ "bia@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_empty Notification.where(saved_search: @ana.saved_searches)
  end

  test "is enqueued on the default queue" do
    assert_enqueued_with(job: SendDailyDigestsJob, queue: "default") do
      SendDailyDigestsJob.perform_later
    end
  end
end
