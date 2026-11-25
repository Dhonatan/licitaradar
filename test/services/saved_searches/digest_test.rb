require "test_helper"

module SavedSearches
  class DigestTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @user = create_user(email_address: "ana@example.com")
      @buffet = @user.saved_searches.create!(name: "Buffet", query: "buffet")
      @palco = @user.saved_searches.create!(name: "Palco", query: "palco")
    end

    test "has one section per notifiable search with new matches" do
      buffet = create_open_tender(object_description: "Serviço de buffet")
      @user.saved_searches.create!(name: "Pausada", query: "buffet", active: false)
      @user.saved_searches.create!(name: "Sem alerta", query: "buffet", notify_daily: false)
      create_user.saved_searches.create!(query: "buffet")

      digest = Digest.new(@user)

      assert_equal [ @buffet, @palco ], digest.saved_searches
      assert_equal 1, digest.sections.size
      assert_equal @buffet, digest.sections.first.saved_search
      assert_equal [ buffet ], digest.sections.first.tenders
      assert_equal 1, digest.tenders_count
      assert_not digest.empty?
    end

    test "is empty for a user who did not confirm the e-mail" do
      create_open_tender(object_description: "Serviço de buffet")
      @user.update!(confirmed_at: nil)

      digest = Digest.new(@user)

      assert_empty digest.saved_searches
      assert digest.empty?
      assert_no_emails { assert_not digest.deliver }
    end

    test "keeps the most urgent tenders per search and counts the rest" do
      tenders = Array.new(Digest::TENDERS_PER_SEARCH + 2) do |index|
        create_open_tender(object_description: "Serviço de buffet", proposals_close_at: (index + 1).days.from_now)
      end

      section = Digest.new(@user).sections.first

      assert_equal tenders.first(Digest::TENDERS_PER_SEARCH), section.tenders
      assert_equal Digest::TENDERS_PER_SEARCH + 2, section.total_count
      assert_equal 2, section.remaining_count
    end

    test "deliver sends one e-mail, records what was sent and moves last_notified_at" do
      buffet = create_open_tender(object_description: "Serviço de buffet")
      palco = create_open_tender(object_description: "Locação de palco")
      now = Time.current.change(usec: 0)

      assert_emails 1 do
        assert Digest.new(@user, now: now).deliver
      end

      assert_equal [ "ana@example.com" ], ActionMailer::Base.deliveries.last.to
      assert_equal [ buffet.id ], @buffet.notifications.pluck(:tender_id)
      assert_equal [ palco.id ], @palco.notifications.pluck(:tender_id)
      assert_equal now, @buffet.reload.last_notified_at
      assert_equal now, @palco.reload.last_notified_at
    end

    test "deliver sends nothing the second time" do
      create_open_tender(object_description: "Serviço de buffet")
      Digest.new(@user).deliver

      assert_no_emails do
        assert_not Digest.new(@user).deliver
      end
      assert_equal 1, Notification.count
    end

    test "deliver without news sends nothing but still moves last_notified_at" do
      now = Time.current.change(usec: 0)

      assert_no_emails do
        assert_not Digest.new(@user, now: now).deliver
      end

      assert_equal now, @buffet.reload.last_notified_at
    end
  end
end
