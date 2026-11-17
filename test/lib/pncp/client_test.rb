require_relative "../../lib_helper"

class Pncp::ClientTest < Minitest::Test
  include PncpTestSupport

  def build_client(*responses, max_retries: 3)
    @slept = []
    @transport = FakeTransport.new(*responses)
    Pncp::Client.new(
      base_url: "https://pncp.test/api/consulta",
      transport: @transport,
      max_retries: max_retries,
      sleeper: ->(seconds) { @slept << seconds }
    )
  end

  def test_open_tenders_builds_the_proposta_query
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ])

    client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31), page: 2, page_size: 100, state: "PE")

    uri = @transport.requests.first[:uri]
    assert_equal "/api/consulta/v1/contratacoes/proposta", uri.path
    assert_equal(
      { "dataFinal" => "20261231", "codigoModalidadeContratacao" => "6", "uf" => "PE", "pagina" => "2", "tamanhoPagina" => "100" },
      @transport.queries.first
    )
  end

  def test_omits_blank_filters_and_clamps_page_size
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ])

    client.open_tenders(modality_id: 8, until_date: "2026-12-31", page_size: 5_000)

    query = @transport.queries.first
    refute query.key?("uf")
    assert_equal "20261231", query["dataFinal"]
    assert_equal "500", query["tamanhoPagina"]
  end

  def test_sends_json_accept_and_identifying_user_agent
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ])

    client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31))

    headers = @transport.requests.first[:headers]
    assert_equal "application/json", headers["Accept"]
    assert_match(/\ALicitaRadar\//, headers["User-Agent"])
  end

  def test_published_tenders_sends_both_dates
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ])

    client.published_tenders(modality_id: 6, from: Date.new(2026, 11, 1), to: Date.new(2026, 11, 17))

    assert_equal "/api/consulta/v1/contratacoes/publicacao", @transport.requests.first[:uri].path
    assert_equal "20261101", @transport.queries.first["dataInicial"]
    assert_equal "20261117", @transport.queries.first["dataFinal"]
  end

  def test_parses_pagination_metadata
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ])

    page = client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31))

    assert_equal 2, page.records.size
    assert_equal 1, page.number
    assert_equal 2, page.total_pages
    assert_equal 3, page.total_records
    refute page.last?
  end

  def test_no_content_response_is_an_empty_last_page
    client = build_client([ 204, "" ])

    page = client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31))

    assert page.empty?
    assert page.last?
  end

  def test_retries_server_errors_with_exponential_backoff
    client = build_client([ 503, "busy" ], [ 502, "" ], [ 200, pncp_fixture("proposta_page_2.json") ])

    page = client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31))

    assert_equal 1, page.records.size
    assert_equal [ 2.0, 4.0 ], @slept
    assert_equal 3, @transport.requests.size
  end

  def test_retries_rate_limiting
    client = build_client([ 429, "" ], [ 200, pncp_fixture("proposta_page_2.json") ])

    client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31))

    assert_equal [ 2.0 ], @slept
  end

  def test_does_not_retry_client_errors
    client = build_client([ 400, "{\"message\":\"parâmetro inválido\"}" ])

    error = assert_raises(Pncp::HttpError) { client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31)) }

    assert_equal 400, error.status
    assert_empty @slept
  end

  def test_gives_up_after_max_retries
    client = build_client([ 500, "" ], [ 500, "" ], [ 500, "" ], max_retries: 2)

    assert_raises(Pncp::HttpError) { client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31)) }
    assert_equal 3, @transport.requests.size
  end

  def test_retries_network_errors_then_wraps_them
    client = build_client(Errno::ECONNRESET.new, Net::ReadTimeout.new, max_retries: 1)

    error = assert_raises(Pncp::Error) { client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31)) }

    assert_match(/Network error/, error.message)
    assert_equal [ 2.0 ], @slept
  end

  def test_invalid_json_raises_pncp_error
    client = build_client([ 200, "<html>Service Unavailable</html>" ])

    assert_raises(Pncp::Error) { client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31)) }
  end

  def test_each_open_tender_walks_every_page
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ], [ 200, pncp_fixture("proposta_page_2.json") ])

    numbers = client.each_open_tender(modality_id: 6, until_date: Date.new(2026, 12, 31)).map { |record| record["numeroControlePNCP"] }

    assert_equal 3, numbers.size
    assert_equal [ "1", "2" ], @transport.queries.map { |query| query["pagina"] }
  end

  def test_each_open_tender_respects_max_pages
    client = build_client([ 200, pncp_fixture("proposta_page_1.json") ])

    records = client.each_open_tender(modality_id: 6, until_date: Date.new(2026, 12, 31), max_pages: 1).to_a

    assert_equal 2, records.size
    assert_equal 1, @transport.requests.size
  end

  def test_base_url_trailing_slash_is_ignored
    transport = FakeTransport.new([ 204, "" ])
    client = Pncp::Client.new(base_url: "https://pncp.test/api/consulta/", transport: transport)

    client.open_tenders(modality_id: 6, until_date: Date.new(2026, 12, 31))

    assert_equal "/api/consulta/v1/contratacoes/proposta", transport.requests.first[:uri].path
  end
end
