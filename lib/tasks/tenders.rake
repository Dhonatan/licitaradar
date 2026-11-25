namespace :tenders do
  desc "Delete tenders closed more than ARCHIVE_AFTER_DAYS days ago (default 180) that nothing refers to"
  task archive: :environment do
    result = ArchiveOldTendersJob.perform_now
    puts "Deleted #{result.deleted_count} tenders closed before #{result.cutoff.iso8601}; " \
         "kept #{result.kept_count} referenced by notifications."
  end
end
