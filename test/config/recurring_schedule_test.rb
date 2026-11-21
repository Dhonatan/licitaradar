require "test_helper"

class RecurringScheduleTest < ActiveSupport::TestCase
  def tasks
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).fetch("production")
  end

  def next_runs(key, count)
    cron = Fugit.parse(tasks.fetch(key).fetch("schedule"))
    time = Time.zone.parse("2026-11-21 08:00")
    Array.new(count) { time = cron.next_time(time).to_t.in_time_zone }
  end

  test "every recurring task is valid for Solid Queue" do
    tasks.each do |key, options|
      task = SolidQueue::RecurringTask.from_configuration(key, **options.symbolize_keys)

      assert task.valid?, "#{key}: #{task.errors.full_messages.to_sentence}"
    end
    assert_equal %w[ send_daily_digests sync_open_tenders ], tasks.keys.sort
  end

  test "the sync runs every 6 hours and the digest daily at 07:00 Brasília time" do
    assert_equal [ "12:30", "18:30", "00:30", "06:30", "12:30" ], next_runs("sync_open_tenders", 5).map { |time| time.strftime("%H:%M") }
    assert_equal [ "2026-11-22 07:00", "2026-11-23 07:00" ], next_runs("send_daily_digests", 2).map { |time| time.strftime("%Y-%m-%d %H:%M") }
  end

  test "the Solid Queue tables accept jobs" do
    job = SolidQueue::Job.enqueue(SendDailyDigestsJob.new)

    assert job.persisted?
    assert_equal "SendDailyDigestsJob", job.class_name
    assert SolidQueue::ReadyExecution.exists?(job_id: job.id)
  end
end
