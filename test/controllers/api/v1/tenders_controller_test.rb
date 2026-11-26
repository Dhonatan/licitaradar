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

      test "show includes the documents and items" do
        tender = create_fetchable_tender
        tender.documents.create!(sequence: 1, title: "Edital", type_id: 2, type_name: "Edital", published_at: Time.zone.parse("2026-11-10 09:15"),
                                 url: "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/12/arquivos/1")
        tender.documents.create!(sequence: 2, title: "Anexo", url: "javascript:alert(1)")
        tender.items.create!(number: 1, description: "Resma de papel A4", material_or_service: "M", quantity: 500, unit: "Pacote",
                             unit_estimated_value: 27.9, total_estimated_value: 13_950, status_name: "Em Andamento",
                             judgment_criterion_name: "Menor preço", benefit_name: "Sem benefício", category_name: "Bens móveis")
        tender.items.create!(number: 2, description: "Manutenção", material_or_service: "S", quantity: 12, unit: "Mês", confidential_budget: true)
        tender.update!(details_fetched_at: Time.zone.parse("2026-11-26 10:00"), details_source_updated_at: tender.source_updated_at)

        assert_no_enqueued_jobs { get api_v1_tender_path(tender), headers: @headers }

        data = response.parsed_body["data"]
        assert_equal({ "status" => "available", "fetched_at" => "2026-11-26T10:00:00-03:00" }, data["details"])
        assert_equal(
          { "sequence" => 1, "title" => "Edital", "type" => { "id" => 2, "name" => "Edital" },
            "url" => "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/12/arquivos/1",
            "published_at" => "2026-11-10T09:15:00-03:00" },
          data["documents"].first
        )
        assert_nil data["documents"].second["url"]
        assert_equal(
          { "number" => 1, "description" => "Resma de papel A4", "kind" => "material", "quantity" => "500.0", "unit" => "Pacote",
            "unit_estimated_value" => "27.9", "total_estimated_value" => "13950.0", "confidential_value" => false,
            "status" => "Em Andamento", "judgment_criterion" => "Menor preço", "benefit" => "Sem benefício",
            "category" => "Bens móveis", "source_updated_at" => nil },
          data["items"].first
        )
        service = data["items"].second
        assert_equal [ "service", nil, nil, true ], service.values_at("kind", "unit_estimated_value", "total_estimated_value", "confidential_value")
      end

      test "show starts the fetch when the details are missing or outdated" do
        tender = create_fetchable_tender

        assert_enqueued_with(job: FetchTenderDetailsJob, args: [ tender ]) { get api_v1_tender_path(tender), headers: @headers }

        data = response.parsed_body["data"]
        assert_equal "pending", data.dig("details", "status")
        assert_nil data["documents"]
        assert_nil data["items"]

        tender.update!(details_fetched_at: 1.day.ago, details_source_updated_at: tender.source_updated_at - 1.day, details_requested_at: nil)
        get api_v1_tender_path(tender), headers: @headers
        assert_equal "refreshing", response.parsed_body.dig("data", "details", "status")
        assert_equal [], response.parsed_body.dig("data", "items")

        get api_v1_tender_path(create_open_tender), headers: @headers
        assert_equal "unavailable", response.parsed_body.dig("data", "details", "status")
      end

      test "the list does not include documents or items" do
        create_open_tender

        get api_v1_tenders_path, headers: @headers

        assert_not response.parsed_body["data"].first.key?("items")
        assert_not response.parsed_body["data"].first.key?("details")
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
