require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  test "requires a login" do
    get api_tokens_path
    assert_redirected_to new_session_path

    post api_tokens_path, params: { api_token: { name: "Portal" } }
    assert_redirected_to new_session_path
    assert_equal 0, ApiToken.count
  end

  test "index lists the user's tokens without revealing them" do
    mine = @user.api_tokens.create!(name: "Portal")
    create_user.api_tokens.create!(name: "De outra pessoa")
    sign_in_as @user

    get api_tokens_path

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "##{ActionView::RecordIdentifier.dom_id(mine)}" do
      assert_select "td", "Portal"
      assert_select "code", "#{mine.token_hint}…"
      assert_select "td", "nunca"
    end
    assert_no_match mine.token, response.body
    assert_select "#new_token", 0
  end

  test "create shows the new token once, outside of any cache" do
    sign_in_as @user

    post api_tokens_path, params: { api_token: { name: "Portal" } }

    assert_response :created
    assert_equal "no-store", response.headers["Cache-Control"]
    api_token = @user.api_tokens.sole
    assert_equal "Portal", api_token.name
    plain = css_select("#new_token code").text
    assert_equal api_token, ApiToken.authenticate(plain)

    get api_tokens_path
    assert_select "#new_token", 0
    assert_no_match plain, response.body
  end

  test "create with an invalid name shows the errors" do
    sign_in_as @user

    post api_tokens_path, params: { api_token: { name: "" } }

    assert_response :unprocessable_content
    assert_select ".form-errors li", "Nome não pode ficar em branco"
    assert_equal 0, ApiToken.count
  end

  test "destroy revokes the user's token only" do
    mine = @user.api_tokens.create!(name: "Portal")
    others = create_user.api_tokens.create!(name: "De outra pessoa")
    sign_in_as @user

    delete api_token_path(others)
    assert_response :not_found

    delete api_token_path(mine)
    assert_redirected_to api_tokens_path
    assert_not ApiToken.exists?(mine.id)
    assert ApiToken.exists?(others.id)
  end
end
