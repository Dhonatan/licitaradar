module Api
  module V1
    # A SavedSearch as JSON in API v1 (documented in docs/API.md). Criteria use the
    # /api/v1/tenders filter names, so links.tenders lists the search's open tenders.
    class SavedSearchSerializer
      attr_reader :saved_search, :urls

      # urls: anything with the app's URL helpers (the controller).
      def initialize(saved_search, urls)
        @saved_search = saved_search
        @urls = urls
      end

      def as_json(*)
        {
          id: saved_search.id,
          name: saved_search.name,
          criteria: {
            q: saved_search.query,
            niche: saved_search.niche_slug,
            states: Array(saved_search.states),
            modality_ids: Array(saved_search.modality_ids),
            min_value: saved_search.min_value,
            max_value: saved_search.max_value,
            closing_within: saved_search.closing_within
          },
          active: saved_search.active,
          notify_daily: saved_search.notify_daily,
          last_notified_at: saved_search.last_notified_at&.iso8601,
          created_at: saved_search.created_at&.iso8601,
          updated_at: saved_search.updated_at&.iso8601,
          links: {
            self: urls.api_v1_saved_search_url(saved_search),
            tenders: urls.api_v1_tenders_url(saved_search.search_params),
            page: urls.tenders_url(saved_search.search_params)
          }
        }
      end
    end
  end
end
