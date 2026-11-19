require "test_helper"

class TendersControllerTest < ActionDispatch::IntegrationTest
  def create_tender(**attributes)
    @sequence = @sequence.to_i + 1
    Tender.create!({
      pncp_control_number: "00000000000191-1-#{@sequence.to_s.rjust(6, "0")}/2026",
      modality_id: 6,
      modality_name: "Pregão - Eletrônico",
      status_id: Tender::PUBLISHED_STATUS_ID,
      status_name: "Divulgada no PNCP",
      state: "PE",
      city: "Exemplópolis",
      agency_name: "Prefeitura Municipal de Exemplópolis",
      agency_cnpj: "00000000000191",
      object_description: "Aquisição de material de expediente",
      estimated_value: 10_000,
      proposals_close_at: 10.days.from_now
    }.merge(attributes))
  end

  test "index lists open tenders with deadline badge and value" do
    tender = create_tender(object_description: "Contratação de agência de publicidade", estimated_value: 1_234.5,
                           proposals_close_at: 3.days.from_now.change(hour: 18))
    create_tender(object_description: "Licitação encerrada", proposals_close_at: 1.day.ago)

    get tenders_path

    assert_response :success
    assert_select "form.search-form[action=?][method=get]", tenders_path
    assert_select "turbo-frame#results" do
      assert_select ".tender-card", 1
      assert_select "##{ActionView::RecordIdentifier.dom_id(tender)} a[href=?][data-turbo-frame='_top']", tender_path(tender), text: /agência de publicidade/
      assert_select ".badge", text: "encerra em 3 dias"
      assert_select ".tender-card__value", text: "R$ 1.234,50"
    end
    assert_select ".results-summary", text: /1\s+licitação aberta encontrada/
  end

  test "index searches by text without accents and keeps the query in the form" do
    create_tender(object_description: "Contratação de agência de publicidade")
    create_tender(object_description: "Aquisição de pneus")

    get tenders_path(q: "agencia")

    assert_select ".tender-card", 1
    assert_select "input[name=q][value=agencia]"
    assert_select ".results-summary", text: /para “agencia”/
  end

  test "index applies filters and niche and pre-fills the form" do
    match = create_tender(object_description: "Organização de eventos com buffet", state: "BA", modality_id: 8, estimated_value: 50_000)
    create_tender(object_description: "Organização de eventos com buffet", state: "PE", modality_id: 8, estimated_value: 50_000)
    create_tender(object_description: "Aquisição de pneus", state: "BA", modality_id: 8, estimated_value: 50_000)

    get tenders_path(niche: "eventos", states: [ "BA" ], modality_ids: [ "8" ], min_value: "10.000", closing_within: "15", sort: "value")

    assert_response :success
    assert_select ".tender-card", 1
    assert_select "##{ActionView::RecordIdentifier.dom_id(match)}"
    assert_select "select[name=niche] option[selected][value=eventos]"
    assert_select "select[name='states[]'] option[selected][value=BA]"
    assert_select "input[type=checkbox][name='modality_ids[]'][value='8'][checked]"
    assert_select "input[name=min_value][value='10000']"
    assert_select "select[name=closing_within] option[selected][value='15']"
    assert_select "select[name=sort] option[selected][value=value]"
  end

  test "index accepts comma-separated lists" do
    create_tender(state: "BA")
    create_tender(state: "SP")
    create_tender(state: "PE")

    get tenders_path(states: "BA,SP")

    assert_select ".tender-card", 2
  end

  test "index shows an empty state" do
    get tenders_path(q: "asfalto")

    assert_response :success
    assert_select ".tender-card", 0
    assert_select ".empty-state", text: /Nenhuma licitação aberta/
  end

  test "index paginates and keeps the filters in the page links" do
    26.times { |i| create_tender(proposals_close_at: (i + 1).days.from_now) }

    get tenders_path(states: [ "PE" ])

    assert_select ".tender-card", 25
    assert_select ".pagination a[rel=next][href=?]", tenders_path(states: [ "PE" ], page: 2)

    get tenders_path(states: [ "PE" ], page: 2)

    assert_select ".tender-card", 1
    assert_select ".pagination a[rel=prev][href=?]", tenders_path(states: [ "PE" ], page: 1)
  end

  test "index ignores garbage params" do
    create_tender

    get tenders_path(page: "-3", min_value: "abc", states: [ "<script>" ], sort: "drop table", niche: "nope")

    assert_response :success
    assert_select ".tender-card", 1
  end

  test "show displays every detail, the countdown and safe external links" do
    tender = create_tender(
      object_description: "Contratação de agência de publicidade",
      additional_info: "Sessão pública no portal de compras.",
      purchase_number: "45", year: 2026, process_number: "2026/0045",
      dispute_mode_name: "Aberto", price_registration: true,
      unit_code: "001", unit_name: "Secretaria de Comunicação",
      agency_sphere: "M", agency_power: "E",
      estimated_value: 0,
      proposals_close_at: 3.days.from_now + 2.hours + 5.minutes,
      pncp_url: "https://pncp.gov.br/app/editais/00000000000191/2026/1",
      origin_url: "https://compras.exemplo.gov.br/pregao/45-2026"
    )

    get tender_path(tender)

    assert_response :success
    assert_select "h1", "Contratação de agência de publicidade"
    assert_select ".countdown", text: /Faltam 3 dias e 2 horas/
    assert_select "dd", text: "Valor sigiloso"
    assert_select "dd", text: "00.000.000/0001-91"
    assert_select "dd", text: "Municipal · Executivo"
    assert_select "dd", text: "001 — Secretaria de Comunicação"
    assert_select "dd", text: "Sim"
    assert_select "dd", text: tender.pncp_control_number
    assert_select "a[href=?][target='_blank'][rel='noopener noreferrer']", tender.pncp_url, text: "Ver edital no PNCP"
    assert_select "a[href=?]", tender.origin_url, text: "Abrir no sistema de origem"
    assert_select "section h2", "Informações complementares"
  end

  test "show handles closed tenders and unsafe or missing links" do
    tender = create_tender(proposals_close_at: 2.days.ago, origin_url: "javascript:alert(1)", pncp_url: nil)

    get tender_path(tender)

    assert_response :success
    assert_select ".countdown", text: "Prazo de propostas encerrado"
    assert_select "a", text: "Abrir no sistema de origem", count: 0
    assert_select "a", text: "Ver edital no PNCP", count: 0
    assert_select "a[href^=javascript]", 0
  end

  test "show returns 404 for unknown tenders" do
    get tender_path(id: 0)

    assert_response :not_found
  end
end
