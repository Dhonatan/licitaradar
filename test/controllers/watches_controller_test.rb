require "test_helper"

class WatchesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create_user
    @tender = create_open_tender(object_description: "Serviço de buffet para formatura")
  end

  test "the watchlist requires login" do
    get watches_path

    assert_redirected_to new_session_path
  end

  test "the watchlist lists the user's tenders by deadline with status badges" do
    travel_to Time.zone.parse("2026-11-27 09:00") do
      today = create_open_tender(object_description: "Locação de palco", proposals_close_at: Time.zone.parse("2026-11-27 18:00"))
      closed = create_open_tender(object_description: "Aquisição de pneus", proposals_close_at: Time.zone.parse("2026-11-20 10:00"))
      later = create_open_tender(object_description: "Material de limpeza", proposals_close_at: Time.zone.parse("2026-12-10 10:00"))
      [ later, closed, today ].each { |tender| Watch.watch!(@user, tender) }
      Watch.watch!(create_user, @tender)
      sign_in_as @user

      get watches_path

      assert_response :success
      assert_select "h1", "Minhas licitações"
      assert_select ".watch-list .tender-card", 3
      assert_select ".watch-list .tender-card__title", text: /Serviço de buffet/, count: 0
      titles = css_select(".watch-list .tender-card__title").map { |node| node.text.strip }
      assert_equal [ "Locação de palco", "Material de limpeza", "Aquisição de pneus" ], titles
      assert_select "##{dom_id(today.watches.first)} .badge--urgent", "encerra hoje"
      assert_select "##{dom_id(later.watches.first)} .badge--ok", "aberta"
      assert_select "##{dom_id(closed.watches.first)} .badge--closed", "encerrada"
      assert_select "##{dom_id(closed.watches.first)}", text: /Encerrou em 20\/11\/2026 às 10:00/
      assert_select "##{dom_id(later.watches.first)} form[action=?] button", tender_watch_path(later), text: "✓ Acompanhando"
    end
  end

  test "the watchlist has an empty state" do
    sign_in_as @user

    get watches_path

    assert_select ".empty-state", text: /ainda não acompanha/
  end

  test "watching a tender from a form redirects back" do
    sign_in_as @user

    assert_difference -> { @user.watches.count }, 1 do
      post tender_watch_path(@tender), headers: { "HTTP_REFERER" => tender_url(@tender) }
    end

    assert_redirected_to tender_url(@tender)
    assert_equal "Você está acompanhando esta licitação.", flash[:notice]

    assert_no_difference -> { Watch.count } do
      post tender_watch_path(@tender)
    end
  end

  test "watching with Turbo swaps the button" do
    sign_in_as @user

    post tender_watch_path(@tender), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=?]", dom_id(@tender, :watch) do
      assert_select "template button", text: "✓ Acompanhando"
    end
    assert @user.watches.exists?(tender: @tender)
  end

  test "unwatching removes the watch and swaps the button back" do
    Watch.watch!(@user, @tender)
    sign_in_as @user

    delete tender_watch_path(@tender), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[target=?] template button", dom_id(@tender, :watch), text: "Acompanhar"
    assert_not @user.watches.exists?
  end

  test "unwatching without Turbo redirects to the tender" do
    Watch.watch!(@user, @tender)
    sign_in_as @user

    delete tender_watch_path(@tender)

    assert_redirected_to tender_path(@tender)
    assert_equal 0, Watch.count
  end

  test "the limit of watches is shown next to the button" do
    sign_in_as @user
    now = Time.current
    tender_ids = Tender.insert_all(Array.new(Watch::MAX_PER_USER) { |index| { pncp_control_number: "00000000000191-1-#{index}/2026", created_at: now, updated_at: now } },
                                   returning: :id).rows.flatten
    Watch.insert_all(tender_ids.map { |id| { user_id: @user.id, tender_id: id, created_at: now, updated_at: now } })

    post tender_watch_path(@tender), as: :turbo_stream

    assert_select "turbo-stream template .watch-button__error", text: /máximo/
    assert_select "turbo-stream template button", text: "Acompanhar"
    assert_not @user.watches.exists?(tender: @tender)
  end

  test "signed-out visitors log in and come back to the tender" do
    get tender_watch_path(@tender)
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: RecordsTestHelper::DEFAULT_PASSWORD }
    assert_redirected_to tender_watch_url(@tender)

    get tender_watch_path(@tender)
    assert_redirected_to tender_path(@tender)
  end

  test "watching an unknown tender is a 404" do
    sign_in_as @user

    post tender_watch_path(tender_id: 0)

    assert_response :not_found
  end

  test "the tender page shows the button for each state" do
    get tender_path(@tender)
    assert_select "##{dom_id(@tender, :watch)}" do
      assert_select "a[href=?]", tender_watch_path(@tender), text: "Acompanhar"
    end

    sign_in_as @user
    get tender_path(@tender)
    assert_select "##{dom_id(@tender, :watch)} form[action=?] button", tender_watch_path(@tender), text: "Acompanhar"

    Watch.watch!(@user, @tender)
    get tender_path(@tender)
    assert_select "##{dom_id(@tender, :watch)} button", text: "✓ Acompanhando"
  end

  test "the results show which tenders the user watches" do
    other = create_open_tender(object_description: "Serviço de buffet infantil")
    Watch.watch!(@user, @tender)
    sign_in_as @user

    get tenders_path(q: "buffet")

    assert_select "##{dom_id(@tender)} ##{dom_id(@tender, :watch)} button", text: "✓ Acompanhando"
    assert_select "##{dom_id(other)} ##{dom_id(other, :watch)} button", text: "Acompanhar"
  end

  test "the navigation links to the watchlist" do
    sign_in_as @user

    get root_path

    assert_select ".site-nav a[href=?]", watches_path, text: "Minhas licitações"
  end
end
