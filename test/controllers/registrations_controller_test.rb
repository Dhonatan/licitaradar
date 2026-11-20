require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def valid_params(**overrides)
    { user: { email_address: "nova@example.com", password: "senha-secreta", password_confirmation: "senha-secreta" }.merge(overrides) }
  end

  test "new shows the sign-up form" do
    get new_registration_path

    assert_response :success
    assert_select "form[action=?][method=post]", registration_path do
      assert_select "input[type=email][name=?]", "user[email_address]"
      assert_select "input[type=password][name=?]", "user[password]"
      assert_select "input[type=password][name=?]", "user[password_confirmation]"
    end
  end

  test "the header links to sign-up and login when signed out" do
    get root_path

    assert_select "nav a[href=?]", new_registration_path
    assert_select "nav a[href=?]", new_session_path
  end

  test "new sends signed-in users home" do
    sign_in_as create_user

    get new_registration_path

    assert_redirected_to root_path
  end

  test "create makes the account and signs it in" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: valid_params(email_address: " Nova@Example.com ")
    end

    user = User.last
    assert_equal "nova@example.com", user.email_address
    assert_equal 1, user.sessions.count
    assert_redirected_to root_url
    assert cookies[:session_id].present?

    follow_redirect!
    assert_select ".flash--notice", /Conta criada/
    assert_select "nav button", "Sair"
  end

  test "create shows errors in Portuguese and keeps the e-mail" do
    create_user(email_address: "nova@example.com")

    assert_no_difference -> { User.count } do
      post registration_path, params: valid_params(password: "curta", password_confirmation: "outra")
    end

    assert_response :unprocessable_content
    assert_select ".form-errors" do
      assert_select "li", text: "E-mail já está em uso"
      assert_select "li", text: "Senha é muito curta (mínimo: 8 caracteres)"
      assert_select "li", text: "Confirmação da senha não é igual a Senha"
    end
    assert_select "input[name=?][value=?]", "user[email_address]", "nova@example.com"
    assert_select "input[name=?][value]", "user[password]", count: 0
  end

  test "create requires the user params" do
    post registration_path, params: { email_address: "nova@example.com" }

    assert_response :bad_request
  end

  test "create is rate limited" do
    10.times { |i| post registration_path, params: valid_params(email_address: "x#{i}@", password: "curta") }

    assert_no_difference -> { User.count } do
      post registration_path, params: valid_params
    end

    assert_redirected_to new_registration_path
    assert_match "Muitas tentativas", flash[:alert]
  end
end
