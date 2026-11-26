module Api
  module V1
    # GET /api/v1/tenders: the same search as the website (Tenders::Search, open tenders
    # only), paginated, with the applied filters in "meta". Invalid filter values are
    # ignored, like on the website. GET /api/v1/tenders/:id: any tender, open or not, with
    # its documents and items (asking for them starts the fetch, like the tender page).
    class TendersController < BaseController
      MAX_PER_PAGE = 100

      def index
        search = Tenders::Search.new(search_params, per_page: per_page)

        render json: {
          data: search.results.map { |tender| TenderSerializer.new(tender, self).as_json },
          meta: {
            page: search.page,
            per_page: search.per_page,
            total_count: search.total_count,
            total_pages: search.total_pages,
            next_page: search.next_page,
            previous_page: search.previous_page,
            sort: search.sort,
            filters: search.to_params.except(:sort)
          }
        }
      end

      def show
        tender = Tender.find(params[:id])
        tender.request_details_fetch
        render json: { data: TenderSerializer.new(tender, self, details: true).as_json }
      end

      private
        # Lists also accept a comma-separated string (?states=PE,PB), see Tenders::Search.
        def search_params
          params.permit(:q, :niche, :min_value, :max_value, :closing_within, :sort, :page, :states, :modality_ids,
                        states: [], modality_ids: [])
        end

        def per_page
          Integer(params[:per_page].to_s, 10, exception: false)&.clamp(1, MAX_PER_PAGE) || Tenders::Search::PER_PAGE
        end
    end
  end
end
