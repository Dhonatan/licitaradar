require "test_helper"

class SyncRunTest < ActiveSupport::TestCase
  test "starts as running with zeroed counters" do
    run = SyncRun.create!(modality_id: 6, started_at: Time.current)

    assert run.running?
    assert_equal [ 0, 0, 0, 0 ], [ run.pages, run.fetched_count, run.upserted_count, run.skipped_count ]
    assert_nil run.duration
  end

  test "requires a modality, a start time and a known status" do
    run = SyncRun.new(status: "exploded")

    assert_not run.valid?
    assert run.errors.key?(:modality_id)
    assert run.errors.key?(:started_at)
    assert run.errors.key?(:status)
  end

  test "last_succeeded_at ignores failed and running runs" do
    finished = 2.hours.ago.change(usec: 0)
    SyncRun.create!(modality_id: 6, started_at: 3.hours.ago, finished_at: finished, status: :succeeded)
    SyncRun.create!(modality_id: 8, started_at: 1.hour.ago, finished_at: 30.minutes.ago, status: :failed)
    SyncRun.create!(modality_id: 4, started_at: 10.minutes.ago)

    assert_equal finished, SyncRun.last_succeeded_at
  end

  test "describes its modality and duration" do
    run = SyncRun.new(modality_id: 8, started_at: Time.current, finished_at: 90.seconds.from_now)

    assert_equal "Dispensa de Licitação", run.modality_name
    assert_in_delta 90, run.duration, 1
  end
end
