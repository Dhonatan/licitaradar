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

  test "requires a positive attempt number" do
    run = SyncRun.new(modality_id: 6, started_at: Time.current, attempt: 0)

    assert_not run.valid?
    assert run.errors.key?(:attempt)
    assert_equal 1, SyncRun.new.attempt
  end

  test "fail_abandoned! closes only runs stuck as running for too long" do
    now = Time.current.change(usec: 0)
    stuck = SyncRun.create!(modality_id: 6, started_at: now - 4.hours)
    busy = SyncRun.create!(modality_id: 8, started_at: now - 10.minutes)
    done = SyncRun.create!(modality_id: 4, started_at: now - 5.hours, finished_at: now - 5.hours, status: :succeeded)

    assert_equal 1, SyncRun.fail_abandoned!(now: now)

    assert stuck.reload.failed?
    assert_equal now, stuck.finished_at
    assert_match "Interrompida", stuck.error_message
    assert busy.reload.running?
    assert done.reload.succeeded?
  end

  test "latest_by_modality returns the most recent run of each modality" do
    SyncRun.create!(modality_id: 6, started_at: 2.days.ago, status: :failed)
    latest_six = SyncRun.create!(modality_id: 6, started_at: 1.hour.ago, status: :succeeded)
    only_eight = SyncRun.create!(modality_id: 8, started_at: 3.hours.ago, status: :failed)

    latest = SyncRun.latest_by_modality

    assert_equal({ 6 => latest_six, 8 => only_eight }, latest)
  end

  test "failures_in_a_row counts failures since the last success" do
    SyncRun.create!(modality_id: 6, started_at: 3.days.ago, status: :failed)
    SyncRun.create!(modality_id: 6, started_at: 2.days.ago, status: :succeeded)
    SyncRun.create!(modality_id: 6, started_at: 1.day.ago, status: :failed)
    SyncRun.create!(modality_id: 6, started_at: 1.hour.ago, status: :failed)
    SyncRun.create!(modality_id: 8, started_at: 1.hour.ago, status: :failed)

    assert_equal 2, SyncRun.failures_in_a_row(6)
    assert_equal 1, SyncRun.failures_in_a_row(8)
    assert_equal 0, SyncRun.failures_in_a_row(4)
  end
end
