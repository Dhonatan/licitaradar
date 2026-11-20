require "test_helper"

class SavedSearchTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "normalizes the criteria with Tenders::Search" do
    saved = @user.saved_searches.create!(name: "  Eventos   no Nordeste ", query: "  buffet   infantil ", niche_slug: "eventos",
                                         states: [ "pe", "XX", "", "PB" ], modality_ids: "8,99", min_value: "1.500,50",
                                         max_value: "", closing_within: "15")

    saved.reload
    assert_equal "Eventos no Nordeste", saved.name
    assert_equal "buffet infantil", saved.query
    assert_equal({ "states" => %w[ PE PB ], "modality_ids" => [ 8 ], "min_value" => "1500.5", "closing_within" => 15 }, saved.filters)
    assert_equal %w[ PE PB ], saved.states
    assert_nil saved.max_value
  end

  test "search_params and search reproduce the saved criteria" do
    saved = @user.saved_searches.create!(query: "buffet", niche_slug: "eventos", states: %w[ BA ], max_value: "50000")

    assert_equal({ q: "buffet", niche: "eventos", states: %w[ BA ], max_value: "50000" }, saved.search_params)

    search = saved.search
    assert_equal "buffet", search.q
    assert_equal "eventos", search.niche.slug
    assert_equal %w[ BA ], search.states
    assert_equal 50_000, search.max_value
  end

  test "search finds the matching open tenders" do
    match = create_open_tender(object_description: "Serviço de buffet para eventos", state: "BA")
    create_open_tender(object_description: "Serviço de buffet para eventos", state: "PE")
    create_open_tender(object_description: "Serviço de buffet para eventos", state: "BA", proposals_close_at: 1.day.ago)

    saved = @user.saved_searches.create!(query: "buffet", states: %w[ BA ])

    assert_equal [ match ], saved.search.results
  end

  test "from_search_params builds from the results page params" do
    saved = SavedSearch.from_search_params({ q: "agência", niche: "marketing-comunicacao", states: "PE,PB", sort: "value", page: "3" },
                                           user: @user)

    assert_equal "agência", saved.query
    assert_equal "marketing-comunicacao", saved.niche_slug
    assert_equal %w[ PE PB ], saved.states
    assert saved.save
    assert_equal({ "states" => %w[ PE PB ] }, saved.reload.filters)
  end

  test "names itself after the criteria when no name is given" do
    assert_equal "“buffet” · Eventos · PE, PB", @user.saved_searches.create!(query: "buffet", niche_slug: "eventos", states: %w[ PE PB ]).name
    assert_equal "Minha busca", @user.saved_searches.create!(min_value: "1000").name
  end

  test "requires at least one criterion" do
    saved = @user.saved_searches.new(name: "Tudo", query: "   ", states: [ "" ])

    assert_not saved.valid?
    assert_match "pelo menos uma palavra-chave", saved.errors[:base].first
  end

  test "rejects unknown niches and long names" do
    saved = @user.saved_searches.new(niche_slug: "astronautica", name: "x" * 101)

    assert_not saved.valid?
    assert_includes saved.errors[:niche_slug], "não está incluído na lista"
    assert saved.errors.key?(:name)
  end

  test "limits saved searches per user" do
    SavedSearch::MAX_PER_USER.times { |i| @user.saved_searches.create!(query: "busca #{i}") }

    extra = @user.saved_searches.new(query: "mais uma")
    assert_not extra.valid?
    assert_match "máximo por conta", extra.errors[:base].first

    assert create_user.saved_searches.new(query: "outra conta").valid?
  end

  test "defaults to active with daily alerts" do
    saved = @user.saved_searches.create!(query: "buffet")

    assert saved.active?
    assert saved.notify_daily?
    assert_nil saved.last_notified_at
  end

  test "notifiable keeps active searches with daily alerts" do
    alerted = @user.saved_searches.create!(query: "a")
    @user.saved_searches.create!(query: "b", notify_daily: false)
    @user.saved_searches.create!(query: "c", active: false)

    assert_equal [ alerted ], SavedSearch.notifiable.to_a
  end

  test "is destroyed with its user" do
    @user.saved_searches.create!(query: "buffet")

    assert_difference -> { SavedSearch.count }, -1 do
      @user.destroy
    end
  end
end
