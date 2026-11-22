require "test_helper"

# Checks that the database can answer the searches with indexes. Sequential scans are
# disabled for the transaction, so the planner falls back to a "Seq Scan" only when no
# index can serve the query (a missing index, or SQL that doesn't match the index
# expression). Real-size plans are discussed in docs/PERFORMANCE.md.
class SearchQueryPlanTest < ActiveSupport::TestCase
  setup do
    create_open_tender(object_description: "Contratação de agência de publicidade")
    create_open_tender(object_description: "Organização de eventos e cerimonial", state: "PB")
    ActiveRecord::Base.connection.execute("SET LOCAL enable_seqscan = off")
  end

  def plan_for(relation)
    ActiveRecord::Base.connection.select_values("EXPLAIN #{relation.to_sql}").join("\n")
  end

  # Only the full-text condition, without the open_for_proposals filters (which could be
  # served by other indexes).
  def full_text_only(search)
    search.scope.unscope(where: %i[ status_id proposals_close_at ])
  end

  test "keyword search uses the GIN index on searchable" do
    search = Tenders::Search.new({ q: "agência de publicidade" })

    assert_match "index_tenders_on_searchable", plan_for(full_text_only(search))
  end

  test "niche search uses the GIN index on searchable" do
    search = Tenders::Search.new({ niche: Niche.all.first.slug })

    assert_match "index_tenders_on_searchable", plan_for(full_text_only(search))
  end

  test "every kind of search can be answered without a sequential scan" do
    searches = [
      {},
      { q: "publicidade" },
      { niche: Niche.all.first.slug, sort: "value" },
      { states: %w[ PE PB ], closing_within: 7 },
      { modality_ids: [ 6, 8 ], min_value: "1000", max_value: "50000", sort: "closing" }
    ]

    searches.each do |params|
      search = Tenders::Search.new(params)
      relation = search.scope.order(proposals_close_at: :asc, id: :asc).limit(search.per_page)

      assert_no_match(/Seq Scan on tenders/, plan_for(relation), "search #{params.inspect}")
    end
  end

  test "saved search matches skip notified tenders through the unique index" do
    saved_search = create_user.saved_searches.create!(name: "Publicidade", query: "publicidade")
    plan = plan_for(SavedSearches::Matcher.new(saved_search, since: 1.day.ago).scope)

    assert_match "index_notifications_on_saved_search_id_and_tender_id", plan
  end
end
