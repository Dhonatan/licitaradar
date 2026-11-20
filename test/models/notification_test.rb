require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @saved_search = create_user.saved_searches.create!(query: "buffet")
    @tender = create_open_tender
  end

  test "allows one notification per tender and saved search" do
    Notification.create!(saved_search: @saved_search, tender: @tender, sent_at: Time.current)
    duplicate = Notification.new(saved_search: @saved_search, tender: @tender, sent_at: Time.current)

    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }

    other_search = create_user.saved_searches.create!(query: "buffet")
    assert Notification.create!(saved_search: other_search, tender: @tender, sent_at: Time.current)
  end

  test "requires sent_at" do
    assert_not Notification.new(saved_search: @saved_search, tender: @tender).valid?
  end

  test "record! inserts new rows and skips tenders already notified" do
    other = create_open_tender
    sent_at = 1.hour.ago.change(usec: 0)

    assert_equal 1, Notification.record!(@saved_search, [ @tender ], sent_at: sent_at)
    assert_equal 1, Notification.record!(@saved_search, [ @tender, other ])
    assert_equal 0, Notification.record!(@saved_search, [ @tender, other ])
    assert_equal 0, Notification.record!(@saved_search, [])

    assert_equal [ @tender.id, other.id ].sort, @saved_search.notifications.pluck(:tender_id).sort
    assert_equal sent_at, @saved_search.notifications.find_by(tender: @tender).sent_at
  end

  test "is removed with its saved search" do
    Notification.record!(@saved_search, [ @tender ])

    assert_difference -> { Notification.count }, -1 do
      @saved_search.destroy
    end
  end

  test "is removed with its user" do
    Notification.record!(@saved_search, [ @tender ])

    assert_difference -> { Notification.count }, -1 do
      @saved_search.user.destroy
    end
  end
end
