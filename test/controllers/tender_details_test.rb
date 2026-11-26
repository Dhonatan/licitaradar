require "test_helper"

# The "Documentos do edital" and "Itens" frame of the tender page (TendersController#details).
class TenderDetailsTest < ActionDispatch::IntegrationTest
  def store_details(tender, items: 3)
    tender.documents.create!(sequence: 1, title: "Edital do Pregão 45/2026", type_name: "Edital", published_at: Time.zone.parse("2026-11-10 09:15"),
                             url: "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/12/arquivos/1")
    tender.documents.create!(sequence: 2, title: "Anexo suspeito", url: "javascript:alert(1)")
    items.times do |index|
      tender.items.create!(number: index + 1, description: "Item #{index + 1}", material_or_service: "M", quantity: 1_500.5, unit: "Unidade",
                           unit_estimated_value: 1.2575, total_estimated_value: 1_886.875 + index)
    end
    tender.update!(details_fetched_at: Time.current, details_source_updated_at: tender.source_updated_at)
  end

  test "the tender page embeds a lazy frame for the details" do
    tender = create_fetchable_tender

    assert_no_enqueued_jobs { get tender_path(tender) }

    assert_select "turbo-frame#tender_details[src=?][loading=lazy]", details_tender_path(tender) do
      assert_select ".details-loading", text: /Carregando documentos/
    end
  end

  test "the first frame request enqueues the fetch and shows a polling loading state" do
    tender = create_fetchable_tender

    assert_enqueued_with(job: FetchTenderDetailsJob, args: [ tender ]) do
      get details_tender_path(tender)
    end

    assert_response :success
    assert_select "turbo-frame#tender_details" do
      assert_select "[data-controller=frame-reload][data-frame-reload-url-value=?]", details_tender_path(tender, poll: 1),
                    text: /Buscando documentos e itens/
    end

    assert_no_enqueued_jobs { get details_tender_path(tender, poll: 1) }
    assert_select "[data-frame-reload-url-value=?]", details_tender_path(tender, poll: 2)
  end

  test "polling stops after the maximum number of reloads" do
    tender = create_fetchable_tender

    get details_tender_path(tender, poll: TendersController::MAX_DETAILS_POLLS + 5)

    assert_select "[data-controller=frame-reload]", 0
    assert_select "turbo-frame#tender_details", text: /Ainda não conseguimos carregar/
  end

  test "shows documents with safe links and items with quantities and values" do
    tender = create_fetchable_tender
    store_details(tender)
    tender.items.create!(number: 4, description: "Manutenção de impressoras", material_or_service: "S", quantity: 12, unit: "Mês",
                         confidential_budget: true, benefit_name: "Sem benefício")

    assert_no_enqueued_jobs { get details_tender_path(tender) }

    assert_select "[data-controller=frame-reload]", 0
    assert_select ".tender-documents h2", "Documentos do edital"
    assert_select ".document-list li", 2
    assert_select "#tender_document_#{tender.documents.first.id}" do
      assert_select ".document-list__type", "Edital"
      assert_select "a.document-list__title[href=?][target=_blank][rel='noopener noreferrer']",
                    "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/12/arquivos/1", text: "Edital do Pregão 45/2026"
      assert_select ".small", "publicado em 10/11/2026"
    end
    assert_select "a[href^=javascript]", 0
    assert_select "span.document-list__title", "Anexo suspeito"

    assert_select ".tender-items h2", /Itens\s+\(4\)/
    assert_select ".items-table tbody tr", 4
    first_row = "#tender_item_#{tender.items.first.id}"
    assert_select "#{first_row} td:nth-child(3)", "1.500,5"
    assert_select "#{first_row} td:nth-child(4)", "Unidade"
    assert_select "#{first_row} td:nth-child(5)", "R$ 1,2575"
    assert_select "#{first_row} td:nth-child(6)", "R$ 1.886,875"
    assert_select "#{first_row} td:nth-child(2) .small", "Material"
    last_row = "#tender_item_#{tender.items.last.id}"
    assert_select "#{last_row} td:nth-child(5)", "sigiloso"
    assert_select "#{last_row} td:nth-child(6)", "sigiloso"
    assert_select "#{last_row} td:nth-child(2) .small", "Serviço · Sem benefício"
  end

  test "shows empty states" do
    tender = create_fetchable_tender
    tender.update!(details_fetched_at: Time.current, details_source_updated_at: tender.source_updated_at)

    get details_tender_path(tender)

    assert_select ".tender-documents", text: /Nenhum documento publicado/
    assert_select ".tender-items", text: /Nenhum item publicado/
  end

  test "caps the items shown and links to the PNCP for the rest" do
    tender = create_fetchable_tender(pncp_url: "https://pncp.gov.br/app/editais/00000000000191/2026/12")
    store_details(tender, items: TendersController::ITEMS_SHOWN + 2)

    get details_tender_path(tender)

    assert_select ".items-table tbody tr", TendersController::ITEMS_SHOWN
    assert_select ".tender-items h2", /\(#{TendersController::ITEMS_SHOWN + 2}\)/
    assert_select ".tender-items a[href=?]", "https://pncp.gov.br/app/editais/00000000000191/2026/12", text: "Ver todos no PNCP"
  end

  test "stale details are shown while a refresh is enqueued" do
    tender = create_fetchable_tender
    store_details(tender)
    tender.update!(source_updated_at: tender.source_updated_at + 1.day)

    assert_enqueued_jobs(1, only: FetchTenderDetailsJob) { get details_tender_path(tender) }

    assert_select ".items-table tbody tr", 3
    assert_select "[data-controller=frame-reload]", 0
  end

  test "tenders the API cannot address get a message instead of a fetch" do
    tender = create_fetchable_tender(sequence: nil)

    assert_no_enqueued_jobs { get details_tender_path(tender) }

    assert_select "turbo-frame#tender_details", text: /não estão disponíveis aqui/
  end

  test "is public and answers 404 for unknown tenders" do
    get details_tender_path(id: 0)

    assert_response :not_found
  end
end
