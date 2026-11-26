# WebMock stubs for the PNCP integration API endpoints read by Tenders::FetchDetails, with
# the fictional fixtures in test/fixtures/files/pncp/.
module PncpDetailsTestHelper
  PNCP_INTEGRATION_URL = "https://pncp.gov.br/api/pncp".freeze
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  # A tender the integration API can address (agency CNPJ + year + sequence).
  def create_fetchable_tender(**attributes)
    create_open_tender(year: 2026, sequence: 12, source_updated_at: Time.zone.parse("2026-11-11 16:42:05"), **attributes)
  end

  def pncp_purchase_url(tender)
    "#{PNCP_INTEGRATION_URL}/v1/orgaos/#{tender.agency_cnpj}/compras/#{tender.year}/#{tender.sequence}"
  end

  # Items 1-3 of the fixtures in one page (shorter than the page size, so the last one).
  def pncp_items_json
    %w[ itens_page_1 itens_page_2 ].flat_map { |name| JSON.parse(file_fixture("pncp/#{name}.json").read) }.to_json
  end

  def stub_tender_details(tender, documents: file_fixture("pncp/arquivos.json").read, items: pncp_items_json, status: 200)
    stub_request(:get, "#{pncp_purchase_url(tender)}/arquivos")
      .to_return(status: status, body: documents, headers: JSON_HEADERS)
    stub_request(:get, "#{pncp_purchase_url(tender)}/itens").with(query: hash_including({}))
      .to_return(status: status, body: items, headers: JSON_HEADERS)
  end
end
