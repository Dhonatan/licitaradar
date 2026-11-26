require "test_helper"

class Tenders::FetchDetailsTest < ActiveSupport::TestCase
  def fetch(tender)
    Tenders::FetchDetails.call(tender, client: Pncp::IntegrationClient.new(max_retries: 0), logger: Logger.new(nil))
  end

  test "stores the active documents and every item and records the fetched version" do
    tender = create_fetchable_tender(details_requested_at: 1.minute.ago)
    stub_tender_details(tender)

    result = fetch(tender)

    assert_equal [ 2, 3, 0 ], [ result.documents_count, result.items_count, result.skipped_count ]
    assert_equal [ 1, 2 ], tender.documents.map(&:sequence)
    edital = tender.documents.first
    assert_equal [ "Edital do Pregão Eletrônico 45/2026", "Edital", 2 ], [ edital.title, edital.type_name, edital.type_id ]
    assert_equal "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/12/arquivos/1", edital.url
    assert_equal Time.zone.parse("2026-11-10 09:15:22 -03:00"), edital.published_at
    assert_match "***.***.***-**", tender.documents.second.title

    assert_equal [ 1, 2, 3 ], tender.items.map(&:number)
    paper = tender.items.first
    assert_equal [ BigDecimal("500"), "Pacote", BigDecimal("27.9"), BigDecimal("13950") ],
                 [ paper.quantity, paper.unit, paper.unit_estimated_value, paper.total_estimated_value ]
    service = tender.items.last
    assert service.confidential_budget
    assert service.confidential_value?

    tender.reload
    assert_not_nil tender.details_fetched_at
    assert_equal tender.source_updated_at, tender.details_source_updated_at
    assert_nil tender.details_requested_at
    assert_not tender.details_stale?
  end

  test "a refetch updates rows and deletes the ones gone from the PNCP" do
    tender = create_fetchable_tender
    stub_tender_details(tender)
    fetch(tender)

    documents = JSON.parse(file_fixture("pncp/arquivos.json").read).first(1)
    documents.first["titulo"] = "Edital retificado"
    items = JSON.parse(pncp_items_json).last(1)
    stub_tender_details(tender, documents: documents.to_json, items: items.to_json)
    fetch(tender)

    assert_equal [ "Edital retificado" ], tender.documents.reload.map(&:title)
    assert_equal [ 3 ], tender.items.reload.map(&:number)
  end

  test "empty answers clear the details and still count as fetched" do
    tender = create_fetchable_tender
    tender.items.create!(number: 9, description: "Antigo")
    stub_tender_details(tender, documents: "", items: "[]")

    result = fetch(tender)

    assert_equal [ 0, 0 ], [ result.documents_count, result.items_count ]
    assert_equal 0, tender.items.count
    assert tender.reload.details_fetched?
  end

  test "skips unidentifiable records and keeps the rest" do
    tender = create_fetchable_tender
    stub_tender_details(tender, items: [ { "descricao" => "sem número" }, { "numeroItem" => 1, "descricao" => "Papel" } ].to_json)

    result = fetch(tender)

    assert_equal 1, result.skipped_count
    assert_equal [ "Papel" ], tender.items.map(&:description)
  end

  test "PNCP errors are raised and nothing is marked as fetched" do
    tender = create_fetchable_tender
    stub_tender_details(tender, status: 500)

    assert_raises(Pncp::HttpError) { fetch(tender) }
    assert_not tender.reload.details_fetched?
  end

  test "refuses tenders the API cannot address" do
    assert_raises(ArgumentError) { fetch(create_fetchable_tender(sequence: nil)) }
  end
end
