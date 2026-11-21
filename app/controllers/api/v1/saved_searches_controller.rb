module Api
  module V1
    # The saved searches of the token's owner. Criteria use the same names as the
    # /api/v1/tenders filters (q, niche, states, ...).
    class SavedSearchesController < BaseController
      # API names => SavedSearch attributes.
      CRITERIA = { q: :query, niche: :niche_slug }.freeze

      def index
        saved_searches = current_user.saved_searches.by_name
        render json: { data: saved_searches.map { |saved_search| SavedSearchSerializer.new(saved_search, self).as_json } }
      end

      def show
        render json: { data: SavedSearchSerializer.new(find_saved_search, self).as_json }
      end

      def create
        saved_search = current_user.saved_searches.new(saved_search_attributes)

        if saved_search.save
          render json: { data: SavedSearchSerializer.new(saved_search, self).as_json }, status: :created,
                 location: api_v1_saved_search_url(saved_search)
        else
          render_error :unprocessable_content, "invalid", saved_search.errors.full_messages.to_sentence,
                       details: saved_search.errors.to_hash.transform_keys { |attribute| CRITERIA.key(attribute) || attribute }
        end
      end

      def destroy
        find_saved_search.destroy
        head :no_content
      end

      private
        def find_saved_search
          current_user.saved_searches.find(params[:id])
        end

        def saved_search_attributes
          params.expect(saved_search: [ :name, :q, :niche, :min_value, :max_value, :closing_within, :active, :notify_daily,
                                        states: [], modality_ids: [] ])
                .transform_keys { |key| CRITERIA.fetch(key.to_sym, key).to_s }
        end
    end
  end
end
