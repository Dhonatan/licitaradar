namespace :pncp do
  desc "Sync tenders open for proposals from the PNCP (limit with MODALITIES=6,8)"
  task sync: :environment do
    modality_ids = ENV["MODALITIES"].to_s.split(",").map(&:strip).compact_blank.map(&:to_i)
    runs = SyncOpenTendersJob.perform_now(modality_ids)

    runs.each do |run|
      counts = "pages=#{run.pages} fetched=#{run.fetched_count} upserted=#{run.upserted_count} skipped=#{run.skipped_count}"
      line = "#{run.modality_id.to_s.rjust(2)} #{run.modality_name.ljust(28)} #{run.status.ljust(9)} #{counts}"
      line += " error=#{run.error_message}" if run.failed?
      puts line
    end

    abort "Some modalities failed to sync." if runs.any?(&:failed?)
  end
end
