require "test_helper"

module SavedSearches
  class MatcherTest < ActiveSupport::TestCase
    setup do
      @saved_search = create_user.saved_searches.create!(query: "buffet", states: %w[ PE ])
    end

    def old_tender(**attributes)
      create_open_tender(**{ object_description: "Serviço de buffet", published_at: 5.days.ago, source_updated_at: 5.days.ago,
                             created_at: 5.days.ago }.merge(attributes))
    end

    test "without a previous notification it returns every open match" do
      match = old_tender
      create_open_tender(object_description: "Aquisição de pneus")
      create_open_tender(object_description: "Serviço de buffet", state: "BA")
      create_open_tender(object_description: "Serviço de buffet", proposals_close_at: 1.hour.ago)

      matcher = Matcher.new(@saved_search)

      assert_nil matcher.since
      assert_equal [ match ], matcher.tenders
      assert_equal 1, matcher.count
      assert matcher.any?
    end

    test "after a notification it keeps tenders published, updated or first synced since then" do
      @saved_search.update!(last_notified_at: 1.day.ago)
      old = old_tender
      published = old_tender(published_at: 2.hours.ago)
      updated = old_tender(source_updated_at: 2.hours.ago)
      synced_late = old_tender(created_at: 2.hours.ago)

      matcher = Matcher.new(@saved_search)

      assert_equal @saved_search.last_notified_at, matcher.since
      assert_equal [ published, updated, synced_late ].map(&:id).sort, matcher.tenders.map(&:id).sort
      assert_not_includes matcher.tenders, old
    end

    test "since can be given explicitly" do
      recent = old_tender(published_at: 2.hours.ago)
      old_tender

      assert_equal [ recent ], Matcher.new(@saved_search, since: 1.day.ago).tenders
    end

    test "skips tenders already notified for this search, even when they change" do
      notified = old_tender(published_at: 2.hours.ago)
      fresh = old_tender(published_at: 1.hour.ago)
      Notification.record!(@saved_search, [ notified ], sent_at: 3.hours.ago)
      @saved_search.update!(last_notified_at: 3.hours.ago)
      notified.update!(source_updated_at: 10.minutes.ago)

      assert_equal [ fresh ], Matcher.new(@saved_search).tenders
    end

    test "notifications for other searches do not count" do
      tender = old_tender
      other_search = create_user.saved_searches.create!(query: "buffet")
      Notification.record!(other_search, [ tender ])

      assert_equal [ tender ], Matcher.new(@saved_search).tenders
    end

    test "uses every criterion of the saved search" do
      @saved_search.update!(niche_slug: "eventos", modality_ids: [ 8 ], max_value: "20000")
      match = old_tender(object_description: "Serviço de buffet para eventos", modality_id: 8, estimated_value: 15_000)
      old_tender(object_description: "Serviço de buffet para eventos", modality_id: 6, estimated_value: 15_000)
      old_tender(object_description: "Serviço de buffet para eventos", modality_id: 8, estimated_value: 50_000)

      assert_equal [ match ], Matcher.new(@saved_search).tenders
    end

    test "orders by the closest deadline and limits" do
      later = old_tender(proposals_close_at: 20.days.from_now)
      sooner = old_tender(proposals_close_at: 2.days.from_now)
      middle = old_tender(proposals_close_at: 9.days.from_now)

      assert_equal [ sooner, middle, later ], Matcher.new(@saved_search).tenders
      assert_equal [ sooner, middle ], Matcher.new(@saved_search).tenders(limit: 2)
    end

    test "returns nothing when everything was already sent" do
      tender = old_tender
      Notification.record!(@saved_search, [ tender ])

      matcher = Matcher.new(@saved_search)

      assert_empty matcher.tenders
      assert_equal 0, matcher.count
      assert_not matcher.any?
    end
  end
end
