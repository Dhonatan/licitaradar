require "test_helper"

class Tenders::SyncTest < ActiveSupport::TestCase
  PROPOSTA_URL = "https://pncp.gov.br/api/consulta/v1/contratacoes/proposta".freeze

  setup do
    # Anything not stubbed explicitly answers "no results".
    stub_request(:get, PROPOSTA_URL).with(query: hash_including({})).to_return(status: 204, body: "")
  end

  def stub_page(modality_id, page, body: nil, status: 200)
    body ||= file_fixture("pncp/proposta_page_#{page}.json").read
    stub_request(:get, PROPOSTA_URL)
      .with(query: hash_including("codigoModalidadeContratacao" => modality_id.to_s, "pagina" => page.to_s))
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  def stub_both_pages(modality_id = 6)
    stub_page(modality_id, 1)
    stub_page(modality_id, 2)
  end

  def sync(modality_ids: [ 6 ], **options)
    Tenders::Sync.call(client: Pncp::Client.new(max_retries: 0), modality_ids: modality_ids, **options)
  end

  test "upserts every tender across pages and records a successful run" do
    stub_both_pages

    runs = sync

    assert_equal 3, Tender.count
    run = runs.sole
    assert run.succeeded?
    assert_equal 6, run.modality_id
    assert_equal [ 2, 3, 3, 0 ], [ run.pages, run.fetched_count, run.upserted_count, run.skipped_count ]
    assert_not_nil run.finished_at
  end

  test "stores normalized attributes, the masked raw record and last_seen_at" do
    stub_both_pages

    sync

    tender = Tender.find_by!(pncp_control_number: "00000000000191-1-000123/2026")
    assert_equal "PE", tender.state
    assert_equal BigDecimal("185000.5"), tender.estimated_value
    assert_equal Time.zone.parse("2026-12-02 09:30"), tender.proposals_close_at
    assert_equal "https://pncp.gov.br/app/editais/00000000000191/2026/123", tender.pncp_url
    assert_includes tender.additional_info, "***.***.***-**"
    assert_not_includes tender.raw.to_json, "529.982.247-25"
    assert_equal "Secretaria de Comunicação", tender.raw.dig("unidadeOrgao", "nomeUnidade")
    assert_not_nil tender.last_seen_at
  end

  test "is idempotent and refreshes changed fields" do
    stub_both_pages
    sync
    first_seen_at = Tender.maximum(:last_seen_at)

    changed = JSON.parse(file_fixture("pncp/proposta_page_1.json").read)
    changed["data"][0]["objetoCompra"] = "Objeto retificado: agência de publicidade."
    changed["data"][0]["situacaoCompraId"] = 3
    stub_page(6, 1, body: changed.to_json)

    sync

    assert_equal 3, Tender.count
    tender = Tender.find_by!(pncp_control_number: "00000000000191-1-000123/2026")
    assert_equal "Objeto retificado: agência de publicidade.", tender.object_description
    assert_equal 3, tender.status_id
    assert_operator tender.last_seen_at, :>, first_seen_at
    assert_equal 2, SyncRun.succeeded.count
  end

  test "keeps one row per tender when a record shows up twice" do
    payload = JSON.parse(file_fixture("pncp/proposta_page_2.json").read)
    payload["data"] << payload["data"].first.merge("objetoCompra" => "Versão mais recente")
    stub_page(6, 1, body: payload.to_json)

    run = sync.sole

    assert run.succeeded?
    assert_equal 1, Tender.count
    assert_equal "Versão mais recente", Tender.sole.object_description
  end

  test "flushes in batches" do
    stub_both_pages

    run = sync(batch_size: 2).sole

    assert run.succeeded?
    assert_equal 3, run.upserted_count
    assert_equal 3, Tender.count
  end

  test "skips and counts records without a control number" do
    payload = JSON.parse(file_fixture("pncp/proposta_page_2.json").read)
    payload["data"] << { "objetoCompra" => "Registro sem número de controle" }
    stub_page(6, 1, body: payload.to_json)

    run = sync.sole

    assert run.succeeded?
    assert_equal [ 2, 1, 1 ], [ run.fetched_count, run.upserted_count, run.skipped_count ]
    assert_equal 1, Tender.count
  end

  test "a failing modality is recorded and does not stop the others" do
    stub_page(6, 1, status: 500, body: "erro interno")
    stub_page(8, 1, body: file_fixture("pncp/proposta_page_2.json").read)

    failed, succeeded = sync(modality_ids: [ 6, 8 ])

    assert failed.failed?
    assert_match(/HTTP 500/, failed.error_message)
    assert_not_nil failed.finished_at
    assert succeeded.succeeded?
    assert_equal 8, succeeded.modality_id
    assert_equal 1, Tender.count
  end

  test "syncs every competitive modality by default with a 120-day horizon" do
    travel_to Time.zone.local(2026, 11, 18, 10, 0) do
      runs = Tenders::Sync.call(client: Pncp::Client.new(max_retries: 0))

      assert_equal Pncp::Modalities::COMPETITIVE, runs.map(&:modality_id)
      assert runs.all?(&:succeeded?)
    end

    assert_requested :get, PROPOSTA_URL, query: hash_including("dataFinal" => "20270318", "tamanhoPagina" => "500"), times: 6
  end

  test "records the attempt number on every run" do
    runs = sync(modality_ids: [ 6, 8 ], attempt: 2)

    assert_equal [ 2, 2 ], runs.map(&:attempt)
  end

  test "closes runs abandoned by a previous process before starting" do
    stuck = SyncRun.create!(modality_id: 6, started_at: 5.hours.ago)

    sync

    assert stuck.reload.failed?
    assert_equal 1, SyncRun.succeeded.count
  end
end
