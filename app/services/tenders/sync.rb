module Tenders
  # Pulls every tender still open for proposals from the PNCP and upserts it into
  # `tenders`, one SyncRun per modality.
  #
  # - Idempotent: rows are keyed by pncp_control_number, so re-running only refreshes them.
  # - Resilient: a modality that fails (API down, bad payload) is recorded as a failed
  #   SyncRun and the remaining modalities still sync.
  # - Records without a control number are skipped and counted.
  # - Runs left "running" by a process that died are closed as failed first.
  # - `attempt` is stored on each SyncRun (SyncOpenTendersJob retries failed modalities).
  #
  #   Tenders::Sync.call                       # all competitive modalities
  #   Tenders::Sync.call(modality_ids: [ 6 ])  # only "Pregão - Eletrônico"
  class Sync
    BATCH_SIZE = 200
    HORIZON_DAYS = 120

    def self.call(...)
      new(...).call
    end

    def initialize(client: Pncp::Client.new, modality_ids: Pncp::Modalities::COMPETITIVE,
                   until_date: Date.current + HORIZON_DAYS, page_size: Pncp::Client::MAX_PAGE_SIZE,
                   max_pages: nil, batch_size: BATCH_SIZE, attempt: 1, logger: Rails.logger)
      @client = client
      @modality_ids = Array(modality_ids).map(&:to_i)
      @until_date = until_date
      @page_size = page_size
      @max_pages = max_pages
      @batch_size = batch_size
      @attempt = attempt
      @logger = logger
    end

    # Returns the SyncRun of each modality, in order.
    def call
      abandoned = SyncRun.fail_abandoned!
      @logger.warn("[Tenders::Sync] closed #{abandoned} abandoned run(s)") if abandoned.positive?

      @modality_ids.map { |modality_id| sync_modality(modality_id) }
    end

    private
      def sync_modality(modality_id)
        run = SyncRun.create!(modality_id: modality_id, started_at: Time.current, attempt: @attempt)
        seen_at = Time.current
        batch = {}

        pages(modality_id).each do |page|
          run.pages += 1
          page.records.each do |record|
            run.fetched_count += 1
            attributes = normalize(record, seen_at)
            if attributes.nil?
              run.skipped_count += 1
              next
            end

            # Pages can shift while we walk them; keep one row per tender in a batch.
            batch[attributes[:pncp_control_number]] = attributes
            run.upserted_count += flush(batch) if batch.size >= @batch_size
          end
        end
        run.upserted_count += flush(batch)

        finish(run, :succeeded)
      rescue StandardError => error
        @logger.error("[Tenders::Sync] modality #{modality_id} failed: #{error.class}: #{error.message}")
        Rails.error.report(error, handled: true, context: { modality_id: modality_id })
        finish(run, :failed, error_message: "#{error.class}: #{error.message}") if run
        run
      end

      def pages(modality_id)
        @client.each_page(max_pages: @max_pages) do |number|
          @client.open_tenders(modality_id: modality_id, until_date: @until_date, page: number, page_size: @page_size)
        end
      end

      def normalize(record, seen_at)
        Pncp::TenderNormalizer.call(record).merge(raw: scrub(record), last_seen_at: seen_at)
      rescue Pncp::InvalidRecord => error
        @logger.warn("[Tenders::Sync] skipped record: #{error.message}")
        nil
      end

      def flush(batch)
        return 0 if batch.empty?

        rows = batch.values
        Tender.upsert_all(rows, unique_by: :pncp_control_number)
        batch.clear
        rows.size
      end

      def finish(run, status, error_message: nil)
        run.update!(status: status, finished_at: Time.current, error_message: error_message)
        counts = "#{run.pages} pages, #{run.fetched_count} fetched, #{run.upserted_count} upserted, #{run.skipped_count} skipped"
        @logger.info("[Tenders::Sync] modality #{run.modality_id} #{status}: #{counts}")
        run
      end

      # The raw record is kept for debugging and future fields; mask CPFs in it too (LGPD).
      def scrub(value)
        case value
        when Hash then value.transform_values { |item| scrub(item) }
        when Array then value.map { |item| scrub(item) }
        when String then Pncp::PiiScrubber.call(value)
        else value
        end
      end
  end
end
