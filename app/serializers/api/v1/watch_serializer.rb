module Api
  module V1
    # A Watch (a tender the user follows) as JSON in API v1 (documented in docs/API.md),
    # with the tender in the same format as GET /api/v1/tenders.
    class WatchSerializer
      attr_reader :watch, :urls

      # urls: anything with the app's URL helpers (the controller).
      def initialize(watch, urls)
        @watch = watch
        @urls = urls
      end

      def as_json(*)
        tender = watch.tender

        {
          id: watch.id,
          tender_id: tender.id,
          proposals_status: tender.proposals_status,
          note: watch.note,
          reminded_close_at: watch.reminded_close_at&.iso8601,
          created_at: watch.created_at&.iso8601,
          tender: TenderSerializer.new(tender, urls).as_json,
          links: { self: urls.api_v1_watch_url(watch) }
        }
      end
    end
  end
end
