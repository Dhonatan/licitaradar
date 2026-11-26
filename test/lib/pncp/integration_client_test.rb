require_relative "../../lib_helper"

class Pncp::IntegrationClientTest < Minitest::Test
  include PncpTestSupport

  PURCHASE = { cnpj: "00.000.000/0001-91", year: 2026, sequence: 12 }.freeze

  def build_client(*responses, max_retries: 3)
    @slept = []
    @transport = FakeTransport.new(*responses)
    Pncp::IntegrationClient.new(
      base_url: "https://pncp.test/api/pncp/",
      transport: @transport,
      max_retries: max_retries,
      sleeper: ->(seconds) { @slept << seconds }
    )
  end

  def item(number)
    { "numeroItem" => number, "descricao" => "Item #{number}" }
  end

  def test_documents_requests_the_arquivos_path_without_query
    client = build_client([ 200, pncp_fixture("arquivos.json") ])

    documents = client.documents(**PURCHASE)

    uri = @transport.requests.first[:uri]
    assert_equal "/api/pncp/v1/orgaos/00000000000191/compras/2026/12/arquivos", uri.path
    assert_nil uri.query
    assert_equal 3, documents.size
    assert_equal "Edital do Pregão Eletrônico 45/2026", documents.first["titulo"]
    assert_equal "application/json", @transport.requests.first[:headers]["Accept"]
  end

  def test_documents_accepts_a_wrapped_list_and_no_content
    client = build_client([ 200, JSON.generate({ "documentos" => [ { "sequencialDocumento" => 1 } ] }) ], [ 204, "" ])

    assert_equal [ { "sequencialDocumento" => 1 } ], client.documents(**PURCHASE)
    assert_equal [], client.documents(**PURCHASE)
  end

  def test_items_sends_paging_parameters
    client = build_client([ 200, pncp_fixture("itens_page_1.json") ])

    items = client.items(**PURCHASE, page: 3, page_size: 2)

    assert_equal "/api/pncp/v1/orgaos/00000000000191/compras/2026/12/itens", @transport.requests.first[:uri].path
    assert_equal({ "pagina" => "3", "tamanhoPagina" => "2" }, @transport.queries.first)
    assert_equal [ 1, 2 ], items.map { |record| record["numeroItem"] }
  end

  def test_all_items_reads_pages_until_a_short_one
    client = build_client([ 200, pncp_fixture("itens_page_1.json") ], [ 200, pncp_fixture("itens_page_2.json") ])

    items = client.all_items(**PURCHASE, page_size: 2)

    assert_equal [ 1, 2, 3 ], items.map { |record| record["numeroItem"] }
    assert_equal [ "1", "2" ], @transport.queries.map { |query| query["pagina"] }
  end

  def test_all_items_stops_on_an_empty_page
    client = build_client([ 200, JSON.generate([ item(1), item(2) ]) ], [ 204, "" ])

    assert_equal [ 1, 2 ], client.all_items(**PURCHASE, page_size: 2).map { |record| record["numeroItem"] }
    assert_equal 2, @transport.requests.size
  end

  def test_all_items_stops_when_the_api_repeats_the_same_page
    page = JSON.generate([ item(1), item(2) ])
    client = build_client([ 200, page ], [ 200, page ])

    assert_equal [ 1, 2 ], client.all_items(**PURCHASE, page_size: 2).map { |record| record["numeroItem"] }
    assert_equal 2, @transport.requests.size
  end

  def test_all_items_respects_max_pages
    client = build_client([ 200, JSON.generate([ item(1), item(2) ]) ], [ 200, JSON.generate([ item(3), item(4) ]) ])

    assert_equal 4, client.all_items(**PURCHASE, page_size: 2, max_pages: 2).size
    assert_equal 2, @transport.requests.size
  end

  def test_retries_server_errors_and_raises_client_errors
    client = build_client([ 503, "" ], [ 200, "[]" ])
    assert_equal [], client.documents(**PURCHASE)
    assert_equal [ 2.0 ], @slept

    client = build_client([ 404, "{}" ])
    error = assert_raises(Pncp::HttpError) { client.documents(**PURCHASE) }
    assert_equal 404, error.status
  end

  def test_requires_a_complete_purchase_reference
    client = build_client

    assert_raises(ArgumentError) { client.documents(cnpj: "123", year: 2026, sequence: 1) }
    assert_raises(ArgumentError) { client.items(cnpj: "00000000000191", year: nil, sequence: 1) }
    assert_empty @transport.requests
  end

  def test_purchase_url
    client = build_client

    assert_equal "https://pncp.test/api/pncp/v1/orgaos/00000000000191/compras/2026/12", client.purchase_url(**PURCHASE)
  end
end
