require "test_helper"

class Tenders::SearchTest < ActiveSupport::TestCase
  def create_tender(**attributes)
    @sequence = @sequence.to_i + 1
    Tender.create!({
      pncp_control_number: "00000000000191-1-#{@sequence.to_s.rjust(6, "0")}/2026",
      modality_id: 6,
      status_id: Tender::PUBLISHED_STATUS_ID,
      state: "PE",
      object_description: "Aquisição de material de expediente",
      estimated_value: 10_000,
      proposals_close_at: 10.days.from_now
    }.merge(attributes))
  end

  def search(**params)
    Tenders::Search.new(params)
  end

  test "without params lists open tenders only, closing soonest first" do
    later = create_tender(proposals_close_at: 20.days.from_now)
    sooner = create_tender(proposals_close_at: 2.days.from_now)
    create_tender(proposals_close_at: 1.day.ago)
    create_tender(status_id: 3)

    result = search

    assert_equal [ sooner, later ], result.results
    assert_equal 2, result.total_count
    assert_equal "closing", result.sort
    assert_not result.filtered?
  end

  test "q matches words regardless of accents, case and plural" do
    agencia = create_tender(object_description: "Contratação de agência de publicidade")
    servicos = create_tender(object_description: "Serviços de limpeza e conservação")
    create_tender(object_description: "Aquisição de pneus")

    assert_equal [ agencia ], search(q: "agencia").results
    assert_equal [ agencia ], search(q: "AGÊNCIA").results
    assert_equal [ servicos ], search(q: "serviço de conservacao").results
    assert_empty search(q: "asfalto").results
  end

  test "q supports web-search syntax: phrases, exclusions and OR" do
    buffet = create_tender(object_description: "Organização de eventos com serviço de buffet")
    som = create_tender(object_description: "Organização de eventos com sonorização")
    limpeza = create_tender(object_description: "Limpeza após eventos esportivos")

    assert_equal [ buffet, som ].sort_by(&:id), search(q: '"organização de eventos"').results.sort_by(&:id)
    assert_equal [ som ], search(q: '"organização de eventos" -buffet').results
    assert_equal [ buffet, limpeza ].sort_by(&:id), search(q: "buffet OR limpeza").results.sort_by(&:id)
  end

  test "q also searches additional info, agency and unit names" do
    by_info = create_tender(additional_info: "Inclui produção audiovisual")
    by_agency = create_tender(agency_name: "Câmara Municipal de Exemplo do Norte")
    by_unit = create_tender(unit_name: "Secretaria de Turismo")

    assert_equal [ by_info ], search(q: "audiovisual").results
    assert_equal [ by_agency ], search(q: "camara").results
    assert_equal [ by_unit ], search(q: "turismo").results
  end

  test "q ranks the most relevant tenders first" do
    weak = create_tender(object_description: "Material de escritório", additional_info: "Entrega na sede da comunicação", proposals_close_at: 1.day.from_now)
    strong = create_tender(object_description: "Comunicação institucional, comunicação digital e comunicação visual", proposals_close_at: 30.days.from_now)

    result = search(q: "comunicação")

    assert_equal "relevance", result.sort
    assert_equal [ strong, weak ], result.results
    assert_equal [ weak, strong ], search(q: "comunicação", sort: "closing").results
  end

  test "an empty or whitespace q is ignored" do
    create_tender

    assert_equal 1, search(q: "   ").total_count
    assert_nil search(q: "   ").q
  end

  test "niche matches any of its keywords and drops its exclusions" do
    publicidade = create_tender(object_description: "Contratação de agência de publicidade")
    redes = create_tender(object_description: "Gestão de redes sociais da prefeitura")
    create_tender(object_description: "Sistema de radiocomunicação e comunicação digital")
    create_tender(object_description: "Iluminação pública")

    result = search(niche: "marketing-comunicacao")

    assert_equal "marketing-comunicacao", result.niche.slug
    assert_equal [ publicidade, redes ].sort_by(&:id), result.results.sort_by(&:id)
    assert_equal "relevance", result.sort
  end

  test "niche and q are combined" do
    create_tender(object_description: "Organização de eventos esportivos")
    buffet = create_tender(object_description: "Organização de eventos com buffet")

    assert_equal [ buffet ], search(niche: "eventos", q: "buffet").results
  end

  test "unknown niche is ignored" do
    create_tender

    result = search(niche: "astronomia")

    assert_nil result.niche
    assert_equal 1, result.total_count
  end

  test "filters by states and modalities given as lists or comma-separated strings" do
    pe = create_tender(state: "PE", modality_id: 6)
    ba = create_tender(state: "BA", modality_id: 8)
    sp = create_tender(state: "SP", modality_id: 6)

    assert_equal [ pe, ba ].sort_by(&:id), search(states: [ "pe", "BA" ]).results.sort_by(&:id)
    assert_equal [ ba, sp ].sort_by(&:id), search(states: "BA,SP").results.sort_by(&:id)
    assert_equal [ ba ], search(modality_ids: [ "8" ]).results
    assert_equal [ pe ], search(states: [ "PE" ], modality_ids: "6").results
  end

  test "invalid states and modalities are dropped" do
    create_tender

    result = search(states: [ "XX", "", "Pernambuco" ], modality_ids: [ "99", "abc", "" ])

    assert_empty result.states
    assert_empty result.modality_ids
    assert_equal 1, result.total_count
  end

  test "filters by value range in Brazilian or plain format" do
    small = create_tender(estimated_value: 5_000)
    medium = create_tender(estimated_value: 50_000)
    large = create_tender(estimated_value: 500_000)

    assert_equal [ medium, large ], search(min_value: "10.000,00", sort: "value").results.reverse
    assert_equal [ small, medium ].sort_by(&:id), search(max_value: "50000").results.sort_by(&:id)
    assert_equal [ medium ], search(min_value: "R$ 10.000", max_value: "100000.50").results
    assert_equal [ medium ], search(min_value: "100000", max_value: "10000").results, "swapped bounds"
    assert_equal 3, search(min_value: "abc").total_count
  end

  test "filters by tenders closing within N days" do
    soon = create_tender(proposals_close_at: 2.days.from_now)
    create_tender(proposals_close_at: 12.days.from_now)

    assert_equal [ soon ], search(closing_within: "3").results
    assert_equal 2, search(closing_within: "nope").total_count
  end

  test "sort by value puts the highest estimate first and unknown values last" do
    unknown = create_tender(estimated_value: nil)
    low = create_tender(estimated_value: 1_000)
    high = create_tender(estimated_value: 900_000)

    assert_equal [ high, low, unknown ], search(sort: "value").results
  end

  test "relevance sort without text falls back to closing date" do
    assert_equal "closing", search(sort: "relevance").sort
    assert_equal "closing", search(sort: "bogus").sort
    assert_equal "value", search(q: "x", sort: "value").sort
  end

  test "paginates 25 per page by default" do
    27.times { |i| create_tender(proposals_close_at: (i + 1).days.from_now) }

    first = search
    last = search(page: "2")

    assert_equal 25, first.results.size
    assert_equal 2, last.results.size
    assert_equal 27, last.total_count
    assert_equal 2, first.total_pages
    assert_equal 2, first.next_page
    assert_nil first.previous_page
    assert_nil last.next_page
    assert_equal 1, last.previous_page
    assert_empty first.results & last.results
  end

  test "invalid pages fall back to sane values" do
    assert_equal 1, search(page: "0").page
    assert_equal 1, search(page: "abc").page
    assert_equal Tenders::Search::MAX_PAGE, search(page: "999999").page
    assert_equal 1, search.total_pages
  end

  test "to_params returns the normalized, non-blank params" do
    params = search(q: " agência  ", niche: "eventos", states: [ "pe", "XX" ], modality_ids: [ "6" ],
                    min_value: "1.500,50", max_value: "", closing_within: "7", sort: "value", page: "3").to_params

    assert_equal({ q: "agência", niche: "eventos", states: [ "PE" ], modality_ids: [ 6 ], min_value: "1500.5",
                   closing_within: 7, sort: "value" }, params)
    assert_equal({ min_value: "10000", page: 2 }, search(min_value: "10000").to_params(page: 2))
  end

  test "accepts ActionController::Parameters" do
    create_tender(state: "BA")
    params = ActionController::Parameters.new(states: [ "BA" ], unexpected: "x").permit(states: [])

    assert_equal 1, Tenders::Search.new(params).total_count
  end
end
