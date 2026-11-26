module Tenders
  # Fetches the documents and items of one tender from the PNCP integration API and
  # replaces the stored ones (rows that disappeared from the PNCP are deleted).
  #
  # - Records the PNCP version it fetched (`details_source_updated_at` = the tender's
  #   `source_updated_at` when the fetch started), so a tender changed by a later sync is
  #   fetched again (Tender#details_stale?).
  # - Documents the PNCP marks inactive (replaced or removed) are left out.
  # - Records that cannot be identified are skipped and counted; PNCP errors are raised
  #   (FetchTenderDetailsJob retries them).
  #
  #   Tenders::FetchDetails.call(tender)  # => #<data Result documents_count=3, items_count=12, skipped_count=0>
  class FetchDetails
    Result = Data.define(:documents_count, :items_count, :skipped_count)

    def self.call(...)
      new(...).call
    end

    def initialize(tender, client: Pncp::IntegrationClient.new, logger: Rails.logger)
      @tender = tender
      @client = client
      @logger = logger
      @skipped_count = 0
    end

    def call
      raise ArgumentError, "tender #{@tender.id} has no PNCP agency CNPJ, year and sequence" unless @tender.details_fetchable?

      version = @tender.source_updated_at
      documents = fetch_documents
      items = fetch_items

      Tender.transaction do
        replace TenderDocument, documents, key: :sequence
        replace TenderItem, items, key: :number
        @tender.update_columns(details_fetched_at: Time.current, details_source_updated_at: version, details_requested_at: nil)
      end

      @logger.info("[Tenders::FetchDetails] tender #{@tender.id}: #{documents.size} documents, #{items.size} items, #{@skipped_count} skipped")
      Result.new(documents_count: documents.size, items_count: items.size, skipped_count: @skipped_count)
    end

    private
      def reference
        { cnpj: @tender.agency_cnpj, year: @tender.year, sequence: @tender.sequence }
      end

      def fetch_documents
        purchase_url = @client.purchase_url(**reference)
        rows = @client.documents(**reference).filter_map do |record|
          normalize { Pncp::DocumentNormalizer.call(record, purchase_url: purchase_url) }
        end
        rows.select { |row| row[:active] }.map { |row| row.except(:active) }.index_by { |row| row[:sequence] }.values
      end

      def fetch_items
        rows = @client.all_items(**reference).filter_map { |record| normalize { Pncp::ItemNormalizer.call(record) } }
        rows.index_by { |row| row[:number] }.values
      end

      def normalize
        yield
      rescue Pncp::InvalidRecord => error
        @skipped_count += 1
        @logger.warn("[Tenders::FetchDetails] tender #{@tender.id}: skipped record: #{error.message}")
        nil
      end

      def replace(model, rows, key:)
        model.where(tender_id: @tender.id).where.not(key => rows.map { |row| row[key] }).delete_all
        return if rows.empty?

        model.upsert_all(rows.map { |row| row.merge(tender_id: @tender.id) }, unique_by: [ :tender_id, key ])
      end
  end
end
