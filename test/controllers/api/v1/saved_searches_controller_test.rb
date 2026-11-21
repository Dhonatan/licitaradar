require "test_helper"

module Api
  module V1
    class SavedSearchesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create_user
        @headers = auth_headers(api_token_for(@user))
      end

      test "every action requires a valid bearer token" do
        saved_search = @user.saved_searches.create!(query: "buffet")

        get api_v1_saved_searches_path
        assert_response :unauthorized
        get api_v1_saved_search_path(saved_search)
        assert_response :unauthorized
        post api_v1_saved_searches_path, params: { saved_search: { q: "palco" } }, as: :json
        assert_response :unauthorized
        delete api_v1_saved_search_path(saved_search)
        assert_response :unauthorized

        assert_equal 1, SavedSearch.count
      end

      test "index lists only the token owner's searches" do
        palco = @user.saved_searches.create!(name: "Palco", query: "palco")
        buffet = @user.saved_searches.create!(name: "Buffet em PE", query: "buffet", niche_slug: "eventos", states: %w[ PE ],
                                              modality_ids: [ 6 ], min_value: "1000", closing_within: 15, notify_daily: false)
        create_user.saved_searches.create!(name: "De outra pessoa", query: "pneus")

        get api_v1_saved_searches_path, headers: @headers

        assert_response :success
        data = response.parsed_body["data"]
        assert_equal [ buffet.id, palco.id ], data.pluck("id")
        json = data.first
        assert_equal "Buffet em PE", json["name"]
        assert_equal({ "q" => "buffet", "niche" => "eventos", "states" => [ "PE" ], "modality_ids" => [ 6 ], "min_value" => "1000",
                       "max_value" => nil, "closing_within" => 15 }, json["criteria"])
        assert_equal [ true, false, nil ], json.values_at("active", "notify_daily", "last_notified_at")
        assert_equal "http://www.example.com/api/v1/saved_searches/#{buffet.id}", json.dig("links", "self")
        assert_equal api_v1_tenders_url(buffet.search_params), json.dig("links", "tenders")
        assert_equal tenders_url(buffet.search_params), json.dig("links", "page")
      end

      test "the tenders link returns the search's open tenders" do
        match = create_open_tender(object_description: "Serviço de buffet", state: "PE")
        create_open_tender(object_description: "Serviço de buffet", state: "BA")
        saved_search = @user.saved_searches.create!(query: "buffet", states: %w[ PE ])

        get api_v1_saved_search_path(saved_search), headers: @headers
        get response.parsed_body.dig("data", "links", "tenders"), headers: @headers

        assert_response :success
        assert_equal [ match.id ], response.parsed_body["data"].pluck("id")
      end

      test "show returns 404 for another user's search" do
        others = create_user.saved_searches.create!(query: "pneus")

        get api_v1_saved_search_path(others), headers: @headers

        assert_response :not_found
        assert_equal "not_found", response.parsed_body.dig("error", "code")
      end

      test "create saves a search with the tenders filter names" do
        post api_v1_saved_searches_path, headers: @headers, as: :json, params: {
          saved_search: { name: "Eventos no Nordeste", q: "buffet", niche: "eventos", states: %w[ pe PB ], modality_ids: [ "8" ],
                          max_value: "50.000,00", closing_within: "30", notify_daily: false }
        }

        assert_response :created
        saved_search = @user.saved_searches.sole
        assert_equal "http://www.example.com/api/v1/saved_searches/#{saved_search.id}", response.headers["Location"]
        assert_equal saved_search.id, response.parsed_body.dig("data", "id")
        assert_equal [ "Eventos no Nordeste", "buffet", "eventos", %w[ PE PB ], [ 8 ], "50000", 30, false ],
                     [ saved_search.name, saved_search.query, saved_search.niche_slug, saved_search.states, saved_search.modality_ids,
                       saved_search.max_value, saved_search.closing_within, saved_search.notify_daily ]
        assert_equal({ "q" => "buffet", "niche" => "eventos", "states" => %w[ PE PB ], "modality_ids" => [ 8 ], "min_value" => nil,
                       "max_value" => "50000", "closing_within" => 30 }, response.parsed_body.dig("data", "criteria"))
      end

      test "create names the search after its criteria when no name is given" do
        post api_v1_saved_searches_path, headers: @headers, as: :json, params: { saved_search: { q: "buffet", states: [ "PE" ] } }

        assert_response :created
        assert_equal "“buffet” · PE", response.parsed_body.dig("data", "name")
      end

      test "create reports validation errors with the API's field names" do
        post api_v1_saved_searches_path, headers: @headers, as: :json, params: { saved_search: { niche: "nao-existe" } }

        assert_response :unprocessable_content
        error = response.parsed_body["error"]
        assert_equal "invalid", error["code"]
        assert_equal "Nicho não está incluído na lista", error["message"]
        assert_equal({ "niche" => [ "não está incluído na lista" ] }, error["details"])

        post api_v1_saved_searches_path, headers: @headers, as: :json, params: { saved_search: { name: "Sem critérios" } }

        assert_response :unprocessable_content
        assert_equal [ "Escolha pelo menos uma palavra-chave, nicho ou filtro para salvar a busca." ],
                     response.parsed_body.dig("error", "details", "base")
        assert_equal 0, SavedSearch.count
      end

  test "create ignores attributes that are not criteria" do
        other_user = create_user

        post api_v1_saved_searches_path, headers: @headers, as: :json,
                                         params: { saved_search: { q: "buffet", user_id: other_user.id, last_notified_at: "2030-01-01" } }

        assert_response :created
        saved_search = SavedSearch.sole
        assert_equal @user, saved_search.user
        assert_nil saved_search.last_notified_at
      end

      test "create without a saved_search object or with broken JSON is a bad request" do
        post api_v1_saved_searches_path, headers: @headers, as: :json, params: { q: "buffet" }

        assert_response :bad_request
        assert_equal "bad_request", response.parsed_body.dig("error", "code")

        post api_v1_saved_searches_path, headers: @headers.merge("Content-Type" => "application/json"), params: "{ quebrado"

        assert_response :bad_request
        assert_equal 0, SavedSearch.count
      end

      test "destroy deletes the token owner's search only" do
        mine = @user.saved_searches.create!(query: "buffet")
        others = create_user.saved_searches.create!(query: "pneus")

        delete api_v1_saved_search_path(others), headers: @headers
        assert_response :not_found

        delete api_v1_saved_search_path(mine), headers: @headers
        assert_response :no_content
        assert_not SavedSearch.exists?(mine.id)
        assert SavedSearch.exists?(others.id)
      end
    end
  end
end
