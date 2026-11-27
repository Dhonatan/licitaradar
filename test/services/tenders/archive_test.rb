require "test_helper"

module Tenders
  class ArchiveTest < ActiveSupport::TestCase
    def notify(tender)
      saved_search = create_user.saved_searches.create!(query: "material")
      Notification.record!(saved_search, [ tender ])
    end

    test "deletes tenders closed more than 180 days ago and keeps the rest" do
      old = create_open_tender(proposals_close_at: 181.days.ago)
      recent = create_open_tender(proposals_close_at: 179.days.ago)
      open = create_open_tender(proposals_close_at: 5.days.from_now)

      result = Archive.new.call

      assert_equal 1, result.deleted_count
      assert_equal 0, result.kept_count
      assert_not Tender.exists?(old.id)
      assert Tender.exists?(recent.id)
      assert Tender.exists?(open.id)
    end

    test "keeps old tenders that were sent in a digest" do
      notified = create_open_tender(proposals_close_at: 200.days.ago)
      notify(notified)
      forgotten = create_open_tender(proposals_close_at: 200.days.ago)

      result = Archive.new.call

      assert_equal 1, result.deleted_count
      assert_equal 1, result.kept_count
      assert Tender.exists?(notified.id)
      assert_not Tender.exists?(forgotten.id)
      assert_equal 1, Notification.count
    end

    test "keeps old tenders that someone watches" do
      watched = create_open_tender(proposals_close_at: 200.days.ago)
      Watch.watch!(create_user, watched)
      forgotten = create_open_tender(proposals_close_at: 200.days.ago)

      result = Archive.new.call

      assert_equal 1, result.deleted_count
      assert_equal 1, result.kept_count
      assert Tender.exists?(watched.id)
      assert_not Tender.exists?(forgotten.id)
    end

    test "tenders without a closing date count from their last update" do
      stale = create_open_tender(proposals_close_at: nil, updated_at: 181.days.ago)
      fresh = create_open_tender(proposals_close_at: nil)

      Archive.new.call

      assert_not Tender.exists?(stale.id)
      assert Tender.exists?(fresh.id)
    end

    test "deletes in batches" do
      3.times { create_open_tender(proposals_close_at: 1.year.ago) }
      batches = 0
      counter = ->(*, payload) { batches += 1 if payload[:sql].start_with?("DELETE FROM \"tenders\"") }

      result = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        Archive.new(batch_size: 2).call
      end

      assert_equal 3, result.deleted_count
      assert_equal 2, batches
      assert_equal 0, Tender.count
    end

    test "the age comes from ARCHIVE_AFTER_DAYS" do
      tender = create_open_tender(proposals_close_at: 40.days.ago)

      with_env("ARCHIVE_AFTER_DAYS" => "30") { Archive.new.call }

      assert_not Tender.exists?(tender.id)
    end

    test "falls back to 180 days when ARCHIVE_AFTER_DAYS is not a positive integer" do
      [ nil, "", "abc", "0", "-5" ].each do |value|
        with_env("ARCHIVE_AFTER_DAYS" => value) { assert_equal 180, Archive.after_days }
      end
      assert_raises(ArgumentError) { Archive.new(after_days: 0) }
    end

    test "reports the cutoff" do
      freeze_time do
        assert_equal 30.days.ago, Archive.new(after_days: 30).call.cutoff
      end
    end
  end
end
