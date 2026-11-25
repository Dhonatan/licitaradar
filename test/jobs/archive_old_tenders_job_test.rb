require "test_helper"
require "rake"

class ArchiveOldTendersJobTest < ActiveJob::TestCase
  test "archives the old tenders and logs the counts" do
    create_open_tender(proposals_close_at: 1.year.ago)
    create_open_tender

    log = StringIO.new
    result = nil
    with_job_logger(ActiveSupport::Logger.new(log)) { result = ArchiveOldTendersJob.perform_now }

    assert_equal 1, result.deleted_count
    assert_equal 1, Tender.count
    assert_match "Tender archive: 1 deleted, 0 kept (referenced)", log.string
  end

  test "is enqueued on the default queue" do
    assert_enqueued_with(job: ArchiveOldTendersJob, queue: "default") do
      ArchiveOldTendersJob.perform_later
    end
  end

  test "tenders:archive runs the job and prints the counts" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("tenders:archive")
    Rake::Task["tenders:archive"].reenable
    create_open_tender(proposals_close_at: 1.year.ago)

    output, = capture_io { Rake::Task["tenders:archive"].invoke }

    assert_match(/\ADeleted 1 tenders closed before \S+; kept 0 referenced by notifications\.$/, output)
  end

  private
    def with_job_logger(logger)
      previous = ActiveJob::Base.logger
      ActiveJob::Base.logger = logger
      yield
    ensure
      ActiveJob::Base.logger = previous
    end
end
