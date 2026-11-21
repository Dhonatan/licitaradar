require "test_helper"

module Api
  module V1
    class TendersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create_user
        @headers = auth_headers(api_token_for(@user))
      end

      test "requires a valid bearer token" do
        tender = create_open_tender

        get api_v1_tenders_path
        assert_response :unauthorized
        assert_equal %(Bearer realm="LicitaRadar"), response.headers["WWW-Authenticate"]
        assert_equal "unauthorized", response.parsed_body.dig("error", "code")

        get api_v1_tenders_path, headers: auth_headers("lr_invalido")
        assert_response :unauthorized

        get api_v1_tender_path(tender), headers: { "Authorization" => "Basic dXNlcjpwYXNz" }
        assert_response :unauthorized
      end

      test "a revoked token stops working" do
        token = api_token_for(@user, name: "Revogado")
        @user.api_tokens.find_by!(name: "Revogado").destroy

        get api_v1_tenders_path, headers: auth_headers(token)

        assert_response :unauthorized
      end

      test "using a token records when it was last used" do
        get api_v1_tenders_path, headers: @headers

        assert_response :success
        assert_not_nil @user.api_tokens.sole.last_used_at
      end

      test "index lists open tenders with metadata" do
        soon = create_open_tender(object_description: "Serviço de buffet", proposals_close_at: 2.days.from_now)
        later = create_open_tender(object_description: "Locação de palco", proposals_close_at: 9.days.from_now)
        create_open_tender(object_description: "Encerrada", proposals_close_at: 1.hour.ago)

        get api_v1_tenders_path, headers: @headers

        assert_response :success
        assert_equal "application/json", response.media_type
        body = response.parsed_body
        assert_equal [ soon.id, later.id ], body["data"].pluck("id")
        assert_equal({ "page" => 1, "per_page" => 25, "total_count" => 2, "total_pages" => 1, "next_page" => nil,
                       "previous_page" => nil, "sort" => "closing", "filters" => {} }, body["meta"])
      end

      test "index serializes every field of a tender" do
        tender = create_open_tender(object_description: "Serviço de buffet", additional_info: "Lote único", estimated_value: 12_345.6,
                                    agency_sphere: "M", agency_power: "E", unit_code: "001", unit_name: "Secretaria de Cultura",
                                    ibge_code: "2600000", year: 2026, sequence: 7, purchase_number: "90007/2026",
                                    proposals_close_at: Time.zone.parse("2030-01-15 14:00"),
                                    pncp_url: "https://pncp.gov.br/app/editais/00000000000191/2026/7", origin_url: "javascript:alert(1)")

        get api_v1_tenders_path, headers: @headers

        json = response.parsed_body["data"].sole
        assert_equal tender.id, json["id"]
        assert_equal tender.pncp_control_number, json["pncp_control_number"]
        assert_equal [ 2026, 7, "90007/2026" ], json.values_at("year", "sequence", "purchase_number")
        assert_equal "Serviço de buffet", json["object"]
        assert_equal "Lote único", json["additional_info"]
        assert_equal({ "id" => 6, "name" => "Pregão - Eletrônico" }, json["modality"])
        assert_equal({ "id" => 1, "name" => "Divulgada no PNCP" }, json["status"])
        assert_equal true, json["open_for_proposals"]
        assert_equal "12345.6", json["estimated_value"]
        assert_equal false, json["confidential_value"]
        assert_equal "2030-01-15T14:00:00-03:00", json["proposals_close_at"]
        assert_equal({ "cnpj" => "00000000000191", "name" => "Prefeitura Municipal de Exemplópolis", "sphere" => "M", "power" => "E" },
                     json["agency"])
        assert_equal({ "code" => "001", "name" => "Secretaria de Cultura" }, json["unit"])
        assert_equal({ "city" => "Exemplópolis", "state" => "PE", "ibge_code" => "2600000" }, json["location"])
        assert_equal({ "self" => "http://www.example.com/api/v1/tenders/#{tender.id}", "page" => "http://www.example.com/tenders/#{tender.id}",
                       "pncp" => "https://pncp.gov.br/app/editais/00000000000191/2026/7", "origin" => nil }, json["links"])
      end

      test "confidential values are null" do
        create_open_tender(estimated_value: 0)

        get api_v1_tenders_path, headers: @headers

        json = response.parsed_body["data"].sole
        assert_nil json["estimated_value"]
        assert_equal true, json["confidential_value"]
      end

      test "index applies the website's filters and reports them" do
        match = create_open_tender(object_description: "Serviço de buffet para eventos", state: "PB", modality_id: 8, estimated_value: 5_000)
        create_open_tender(object_description: "Serviço de buffet para eventos", state: "BA", modality_id: 8, estimated_value: 5_000)
        create_open_tender(object_description: "Serviço de buffet para eventos", state: "PB", modality_id: 6, estimated_value: 5_000)
        create_open_tender(object_description: "Serviço de buffet para eventos", state: "PB", modality_id: 8, estimated_value: 50_000)
        create_open_tender(object_description: "Aquisição de pneus", state: "PB", modality_id: 8, estimated_value: 5_000)

        get api_v1_tenders_path(q: "bufê OR buffet", niche: "eventos", states: "PE,PB", modality_ids: [ "8" ], max_value: "10.000,00",
                                closing_within: "30"), headers: @headers

        assert_response :success
        assert_equal [ match.id ], response.parsed_body["data"].pluck("id")
        assert_equal({ "q" => "bufê OR buffet", "niche" => "eventos", "states" => %w[ PE PB ], "modality_ids" => [ 8 ],
                       "max_value" => "10000", "closing_within" => 30 }, response.parsed_body.dig("meta", "filters"))
        assert_equal "relevance", response.parsed_body.dig("meta", "sort")
      end

      test "invalid filter values are ignored" do
        create_open_tender

        get api_v1_tenders_path(states: "XX", modality_ids: "abc", niche: "nao-existe", min_value: "muito"), headers: @headers

        assert_response :success
        assert_equal 1, response.parsed_body.dig("meta", "total_count")
        assert_equal({}, response.parsed_body.dig("meta", "filters"))
      end

      test "index paginates with per_page up to 100" do
        tenders = Array.new(3) { |index| create_open_tender(proposals_close_at: (index + 1).days.from_now) }

        get api_v1_tenders_path(per_page: 2, page: 2), headers: @headers

        body = response.parsed_body
        assert_equal [ tenders.last.id ], body["data"].pluck("id")
        assert_equal [ 2, 2, 3, 2, nil, 1 ], body["meta"].values_at("page", "per_page", "total_count", "total_pages", "next_page", "previous_page")

        get api_v1_tenders_path(per_page: 1000), headers: @headers
        assert_equal 100, response.parsed_body.dig("meta", "per_page")

        get api_v1_tenders_path(per_page: "abc"), headers: @headers
        assert_equal 25, response.parsed_body.dig("meta", "per_page")
      end

      test "sorts by value" do
        cheap = create_open_tender(estimated_value: 1_000)
        expensive = create_open_tender(estimated_value: 90_000)

        get api_v1_tenders_path(sort: "value"), headers: @headers

        assert_equal [ expensive.id, cheap.id ], response.parsed_body["data"].pluck("id")
        assert_equal "value", response.parsed_body.dig("meta", "sort")
      end

      test "show returns any tender, even a closed one" do
        closed = create_open_tender(object_description: "Encerrada", proposals_close_at: 1.day.ago)

        get api_v1_tender_path(closed), headers: @headers

        assert_response :success
        assert_equal closed.id, response.parsed_body.dig("data", "id")
        assert_equal false, response.parsed_body.dig("data", "open_for_proposals")
      end

      test "show answers 404 as JSON for unknown tenders" do
        get api_v1_tender_path(0), headers: @headers

        assert_response :not_found
        assert_equal({ "error" => { "code" => "not_found", "message" => "Registro não encontrado." } }, response.parsed_body)
      end

      test "requests are rate limited per token" do
        other_headers = auth_headers(api_token_for(create_user))

        BaseController::RATE_LIMIT.times { get api_v1_tender_path(0), headers: @headers }
        assert_response :not_found

        get api_v1_tender_path(0), headers: @headers
        assert_response :too_many_requests
        assert_equal "rate_limited", response.parsed_body.dig("error", "code")

        get api_v1_tender_path(0), headers: other_headers
        assert_response :not_found
      end
    end
  end
end
