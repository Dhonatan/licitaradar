require "test_helper"

class UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email_address: "ana@example.com")
    @buffet = @user.saved_searches.create!(name: "Buffet", query: "buffet")
    @palco = @user.saved_searches.create!(name: "Palco", query: "palco")
    @other = create_user.saved_searches.create!(name: "De outra pessoa", query: "buffet")
  end

  test "a saved search link asks for confirmation without changing anything" do
    token = @buffet.generate_token_for(:digest_unsubscribe)

    get unsubscribe_path(token)

    assert_response :success
    assert_select "h1", "Alerta da busca “Buffet”"
    assert_select "form[action=?][method=post] button", unsubscribe_path(token), text: "Parar os alertas"
    assert @buffet.reload.notify_daily?
  end

  test "confirming stops only that search's alert, without a login" do
    token = @buffet.generate_token_for(:digest_unsubscribe)

    post unsubscribe_path(token)

    assert_redirected_to unsubscribe_path(token)
    assert_not @buffet.reload.notify_daily?
    assert @palco.reload.notify_daily?
    assert @other.reload.notify_daily?

    follow_redirect!
    assert_select ".flash--notice", "Pronto! Você não vai mais receber esses alertas por e-mail."
    assert_select "p", "O alerta diário desta busca está desativado."
    assert_select "form[action=?]", unsubscribe_path(token), count: 0
  end

  test "an account link stops every alert of the account" do
    token = @user.generate_token_for(:digest_unsubscribe_all)

    get unsubscribe_path(token)
    assert_select "h1", "Alertas diários de ana@example.com"

    post unsubscribe_path(token), params: { "List-Unsubscribe" => "One-Click" }

    assert_redirected_to unsubscribe_path(token)
    assert_not @buffet.reload.notify_daily?
    assert_not @palco.reload.notify_daily?
    assert @other.reload.notify_daily?
  end

  test "one-click unsubscribes work with forgery protection on" do
    ActionController::Base.allow_forgery_protection = true

    post unsubscribe_path(@user.generate_token_for(:digest_unsubscribe_all)), params: { "List-Unsubscribe" => "One-Click" }

    assert_response :see_other
    assert_not @buffet.reload.notify_daily?
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "invalid or swapped tokens are rejected" do
    [ "invalido", @buffet.generate_token_for(:digest_unsubscribe).reverse, @user.password_reset_token ].each do |token|
      get unsubscribe_path(token)
      assert_response :not_found
      assert_select "h1", "Link inválido"

      post unsubscribe_path(token)
      assert_response :not_found
    end

    assert @buffet.reload.notify_daily?
    assert @palco.reload.notify_daily?
  end
end
