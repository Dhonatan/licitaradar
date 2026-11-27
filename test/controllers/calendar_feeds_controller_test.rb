require "test_helper"

class CalendarFeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @tender = create_open_tender(object_description: "Serviço de buffet", proposals_close_at: 3.days.from_now)
    Watch.watch!(@user, @tender)
  end

  test "the secret URL answers the iCalendar feed without login" do
    get calendar_feed_path(@user.calendar_token)

    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_equal "utf-8", response.charset
    assert_match(/\Ainline; filename="licitaradar.ics"/, response.headers["Content-Disposition"])
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "SUMMARY:Prazo: Serviço de buffet"
    assert_includes response.body, "URL:http://www.example.com/tenders/#{@tender.id}"
  end

  test "the path ends in .ics" do
    assert_equal "/calendario/#{@user.calendar_token}.ics", calendar_feed_path(@user.calendar_token)
  end

  test "unknown or blank tokens are a 404" do
    get calendar_feed_path("nao-existe")
    assert_response :not_found

    @user.update_column(:calendar_token, nil)
    get "/calendario/.ics"
    assert_response :not_found
  end

  test "the watchlist shows the feed URL and a webcal link" do
    sign_in_as @user

    get watches_path

    assert_select "#calendar" do
      assert_select ".calendar-feed__url", calendar_feed_url(@user.calendar_token)
      assert_select "a[href=?]", calendar_feed_url(@user.calendar_token).sub("http://", "webcal://"), text: "Assinar no calendário"
      assert_select "form[action=?] button", calendar_token_path, text: "Gerar novo link"
    end
  end

  test "users without a token are offered one" do
    @user.update_column(:calendar_token, nil)
    sign_in_as @user

    get watches_path
    assert_select "#calendar form[action=?] button", calendar_token_path, text: "Gerar link do calendário"

    post calendar_token_path
    assert_redirected_to watches_path(anchor: "calendar")
    assert_equal "Link do calendário gerado.", flash[:notice]
    assert_equal 32, @user.reload.calendar_token.length
  end

  test "regenerating the token kills the old URL" do
    old_token = @user.calendar_token
    sign_in_as @user

    post calendar_token_path

    assert_match(/parou de funcionar/, flash[:notice])
    assert_not_equal old_token, @user.reload.calendar_token
    get calendar_feed_path(old_token)
    assert_response :not_found
    get calendar_feed_path(@user.calendar_token)
    assert_response :success
  end

  test "regenerating requires login" do
    post calendar_token_path

    assert_redirected_to new_session_path
  end
end
