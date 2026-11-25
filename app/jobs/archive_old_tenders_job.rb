# Weekly clean-up of tenders closed long ago (see Tenders::Archive). Scheduled in
# config/recurring.yml; run it by hand with `bin/rails tenders:archive`.
class ArchiveOldTendersJob < ApplicationJob
  queue_as :default

  def perform
    archive = Tenders::Archive.new
    result = archive.call

    logger.info "Tender archive: #{result.deleted_count} deleted, #{result.kept_count} kept (referenced), " \
                "closed before #{result.cutoff.iso8601} (#{archive.after_days} days)"
    result
  end
end
