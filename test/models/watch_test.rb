require "test_helper"

class WatchTest < ActiveSupport::TestCase
  setup do
    @user = create_user
  end

  test "a user watches a tender once" do
    tender = create_open_tender

    first = Watch.watch!(@user, tender)
    second = Watch.watch!(@user, tender)

    assert first.persisted?
    assert_equal first, second
    assert_equal 1, @user.watches.count
    assert_equal [ tender ], @user.watched_tenders.to_a
    assert_not @user.watches.new(tender: tender).valid?
  end

  test "different users watch the same tender independently" do
    tender = create_open_tender

    Watch.watch!(@user, tender)
    Watch.watch!(create_user, tender)

    assert_equal 2, tender.watches.count
  end

  test "the database refuses a second watch of the same tender" do
    tender = create_open_tender
    existing = Watch.watch!(@user, tender)

    assert_raises(ActiveRecord::RecordNotUnique) { Watch.new(user: @user, tender: tender).save(validate: false) }
    assert_equal existing, Watch.watch!(@user, tender)
  end

  test "a user watches at most MAX_PER_USER tenders" do
    now = Time.current
    tender_ids = Tender.insert_all(Array.new(Watch::MAX_PER_USER) { |index| { pncp_control_number: "00000000000191-1-#{index}/2026", created_at: now, updated_at: now } },
                                   returning: :id).rows.flatten
    Watch.insert_all(tender_ids.map { |id| { user_id: @user.id, tender_id: id, created_at: now, updated_at: now } })

    watch = Watch.watch!(@user, create_open_tender)

    assert_not watch.persisted?
    assert_match(/máximo/, watch.errors.full_messages.to_sentence)
  end

  test "by_deadline lists open tenders by closest deadline, then closed ones, then those without a deadline" do
    later = create_open_tender(proposals_close_at: 10.days.from_now)
    no_deadline = create_open_tender(proposals_close_at: nil)
    closed_long_ago = create_open_tender(proposals_close_at: 20.days.ago)
    sooner = create_open_tender(proposals_close_at: 2.days.from_now)
    closed_recently = create_open_tender(proposals_close_at: 1.day.ago)
    [ later, no_deadline, closed_long_ago, sooner, closed_recently ].each { |tender| Watch.watch!(@user, tender) }

    assert_equal [ sooner, later, closed_recently, closed_long_ago, no_deadline ], @user.watches.by_deadline.map(&:tender)
  end

  test "watches go away with the user and the tender" do
    tender = create_open_tender
    other = create_open_tender
    Watch.watch!(@user, tender)
    Watch.watch!(create_user, other)

    @user.destroy
    other.destroy

    assert_equal 0, Watch.count
  end
end
