require "test_helper"

# N+1 guard: the number of SQL queries of a page must not grow with the number of
# records it lists. Queries answered by Active Record's query cache count too (the cache
# can outlive a request in tests, and an N+1 is a bug even when it hits the cache).
class QueryCountsTest < ActionDispatch::IntegrationTest
  IGNORED_QUERIES = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i

  def count_queries(&block)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(IGNORED_QUERIES)
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  def queries_with(records, &request)
    records.call
    request.call # warm up (schema and statement caches)
    count_queries(&request)
  end

  test "the results page runs the same queries for 1 or 25 tenders" do
    few = queries_with(-> { create_open_tender }) { get tenders_path }
    many = queries_with(-> { 24.times { create_open_tender } }) { get tenders_path }

    assert_response :success
    assert_select ".tender-card", 25
    assert_equal few, many
  end

  test "the API tenders index runs the same queries for 1 or 25 tenders" do
    headers = auth_headers(api_token_for(create_user))

    few = queries_with(-> { create_open_tender }) { get api_v1_tenders_path, headers: headers }
    many = queries_with(-> { 24.times { create_open_tender } }) { get api_v1_tenders_path, headers: headers }

    assert_equal 25, response.parsed_body["data"].size
    assert_equal few, many
  end

  test "the API saved searches index runs the same queries for 1 or 10 searches" do
    user = create_user
    headers = auth_headers(api_token_for(user))
    add_searches = ->(count) { count.times { |index| user.saved_searches.create!(name: "Busca #{SecureRandom.hex(4)}", query: "obra #{index}") } }

    few = queries_with(-> { add_searches.call(1) }) { get api_v1_saved_searches_path, headers: headers }
    many = queries_with(-> { add_searches.call(9) }) { get api_v1_saved_searches_path, headers: headers }

    assert_equal 10, response.parsed_body["data"].size
    assert_equal few, many
  end

  test "the saved searches page only adds the open tenders count per search" do
    user = create_user
    sign_in_as user
    add_searches = ->(count) { count.times { |index| user.saved_searches.create!(name: "Busca #{SecureRandom.hex(4)}", query: "obra #{index}") } }

    one = queries_with(-> { add_searches.call(1) }) { get saved_searches_path }
    five = queries_with(-> { add_searches.call(4) }) { get saved_searches_path }

    # One COUNT per card ("Ver N licitações abertas"), bounded by SavedSearch::MAX_PER_USER.
    assert_equal one + 4, five
  end

  test "the watchlist runs the same queries for 1 or 10 watched tenders" do
    user = create_user
    sign_in_as user
    add_watches = ->(count) { count.times { Watch.watch!(user, create_open_tender) } }

    few = queries_with(-> { add_watches.call(1) }) { get watches_path }
    many = queries_with(-> { add_watches.call(9) }) { get watches_path }

    assert_select ".watch-list .tender-card", 10
    assert_equal few, many
  end

  test "the results page adds one query for a signed-in user's watched tenders" do
    user = create_user
    Watch.watch!(user, create_open_tender)
    signed_out = queries_with(-> { 24.times { create_open_tender } }) { get tenders_path }
    sign_in_as user

    signed_in = queries_with(-> { nil }) { get tenders_path }

    assert_select ".tender-card .watch-button form", 25
    assert_operator signed_in, :<=, signed_out + 3 # session, user, watches
  end
end
