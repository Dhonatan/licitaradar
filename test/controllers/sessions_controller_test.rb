require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = create_user(email_address: "ana@example.com", password: "senha-secreta") }

  test "new shows the login form" do
    get new_session_path

    assert_response :success
    assert_select "form[action=?][method=post]", session_path do
      assert_select "input[type=email][name=email_address]"
      assert_select "input[type=password][name=password]"
    end
    assert_select "a[href=?]", new_password_path
  end

  test "new sends signed-in users home" do
    sign_in_as @user

    get new_session_path

    assert_redirected_to root_path
  end

  test "create signs in with valid credentials, ignoring e-mail case" do
    assert_difference -> { @user.sessions.count }, 1 do
      post session_path, params: { email_address: " ANA@example.com", password: "senha-secreta" }
    end

    assert_redirected_to root_url
    assert cookies[:session_id].present?

    follow_redirect!
    assert_select ".flash--notice", "Bem-vindo de volta!"
    assert_select "nav button", "Sair"
  end

  test "create rejects a wrong password" do
    assert_no_difference -> { Session.count } do
      post session_path, params: { email_address: "ana@example.com", password: "errada" }
    end

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
    follow_redirect!
    assert_select ".flash--alert", "E-mail ou senha incorretos."
  end

  test "create rejects an unknown e-mail with the same message" do
    post session_path, params: { email_address: "ninguem@example.com", password: "senha-secreta" }

    assert_redirected_to new_session_path
    assert_equal "E-mail ou senha incorretos.", flash[:alert]
  end

  test "create is rate limited" do
    10.times { post session_path, params: { email_address: "ana@example.com", password: "errada" } }
    assert_equal "E-mail ou senha incorretos.", flash[:alert]

    assert_no_difference -> { Session.count } do
      post session_path, params: { email_address: "ana@example.com", password: "senha-secreta" }
    end

    assert_redirected_to new_session_path
    assert_match "Muitas tentativas", flash[:alert]
  end

  test "destroy signs out" do
    sign_in_as @user

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end

    assert_redirected_to root_path
    assert cookies[:session_id].blank?
  end

  test "public pages work signed out and show the login link" do
    get root_path

    assert_response :success
    assert_select "nav a[href=?]", new_session_path
  end
end
