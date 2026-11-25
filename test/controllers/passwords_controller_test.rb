require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @user = create_user(email_address: "ana@example.com", password: "senha-secreta") }

  test "new shows the reset request form" do
    get new_password_path

    assert_response :success
    assert_select "form[action=?] input[type=email][name=email_address]", passwords_path
  end

  test "create e-mails a reset link to existing accounts" do
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ] do
      post passwords_path, params: { email_address: " Ana@Example.com " }
    end

    assert_redirected_to new_session_path
    assert_match "Se existir uma conta com esse e-mail", flash[:notice]
  end

  test "create gives the same answer for unknown addresses without sending anything" do
    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: "ninguem@example.com" }
    end

    assert_redirected_to new_session_path
    assert_match "Se existir uma conta com esse e-mail", flash[:notice]
  end

  test "edit shows the new password form for a valid token" do
    get edit_password_path(@user.password_reset_token)

    assert_response :success
    assert_select "form input[type=password][name=password]"
    assert_select "form input[type=password][name=password_confirmation]"
  end

  test "edit rejects an invalid token" do
    get edit_password_path("token-invalido")

    assert_redirected_to new_password_path
    assert_match "inválido ou expirou", flash[:alert]
  end

  test "edit rejects an expired token" do
    token = @user.password_reset_token

    travel 16.minutes do
      get edit_password_path(token)
    end

    assert_redirected_to new_password_path
  end

  test "update changes the password and signs out every session" do
    @user.sessions.create!

    put password_path(@user.password_reset_token), params: { password: "senha-nova-123", password_confirmation: "senha-nova-123" }

    assert_redirected_to new_session_path
    assert_equal 0, @user.sessions.count
    assert User.authenticate_by(email_address: "ana@example.com", password: "senha-nova-123")
  end

  test "update confirms an unconfirmed address, since the reset link reached it" do
    @user.update!(confirmed_at: nil)

    put password_path(@user.password_reset_token), params: { password: "senha-nova-123", password_confirmation: "senha-nova-123" }

    assert @user.reload.confirmed?
  end

  test "update keeps the token usable when the confirmation does not match" do
    token = @user.password_reset_token

    put password_path(token), params: { password: "senha-nova-123", password_confirmation: "outra" }

    assert_response :unprocessable_content
    assert_select ".form-errors", /Confirmação da senha não é igual a Senha/
    assert_select "form[action=?]", password_path(token)
    assert User.authenticate_by(email_address: "ana@example.com", password: "senha-secreta")
  end

  test "update rejects a blank or short password" do
    token = @user.password_reset_token

    put password_path(token), params: { password: "", password_confirmation: "" }
    assert_response :unprocessable_content
    assert_select ".form-errors", /Senha não pode ficar em branco/

    put password_path(token), params: { password: "curta", password_confirmation: "curta" }
    assert_response :unprocessable_content
    assert_select ".form-errors", /Senha é muito curta/

    assert User.authenticate_by(email_address: "ana@example.com", password: "senha-secreta")
  end

  test "a used token cannot be used again" do
    token = @user.password_reset_token
    put password_path(token), params: { password: "senha-nova-123", password_confirmation: "senha-nova-123" }

    get edit_password_path(token)

    assert_redirected_to new_password_path
  end
end
