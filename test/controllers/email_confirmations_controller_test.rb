require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @user = create_user(email_address: "ana@example.com", confirmed: false) }

  def token_for(user)
    user.generate_token_for(:email_confirmation)
  end

  test "the link confirms the account and sends signed-out visitors to the login" do
    get email_confirmation_path(token_for(@user))

    assert_redirected_to new_session_path
    assert_match "ana@example.com confirmado", flash[:notice]
    assert @user.reload.confirmed?
  end

  test "the link sends signed-in users home" do
    sign_in_as @user

    get email_confirmation_path(token_for(@user))

    assert_redirected_to root_path
    assert @user.reload.confirmed?
  end

  test "opening the link twice is harmless" do
    token = token_for(@user)
    get email_confirmation_path(token)

    assert_no_changes -> { @user.reload.confirmed_at } do
      get email_confirmation_path(token)
    end
    assert_redirected_to new_session_path
  end

  test "an invalid or expired link points to the resend page" do
    get email_confirmation_path("token-invalido")

    assert_redirected_to new_email_confirmation_path
    assert_match "inválido ou expirou", flash[:alert]

    token = token_for(@user)
    travel 4.days do
      get email_confirmation_path(token)
    end

    assert_redirected_to new_email_confirmation_path
    assert_not @user.reload.confirmed?
  end

  test "the link of an e-mail change switches the address" do
    user = create_user(email_address: "bia@example.com")
    user.update!(unconfirmed_email: "bia.nova@example.com")
    sign_in_as user

    get email_confirmation_path(token_for(user))

    assert_redirected_to root_path
    assert_match "bia.nova@example.com confirmado", flash[:notice]
    assert_equal "bia.nova@example.com", user.reload.email_address
    assert_nil user.unconfirmed_email
  end

  test "the link of an e-mail change fails when the address was taken meanwhile" do
    user = create_user(email_address: "bia@example.com")
    user.update!(unconfirmed_email: "bia.nova@example.com")
    token = token_for(user)
    create_user(email_address: "bia.nova@example.com")
    sign_in_as user

    get email_confirmation_path(token)

    assert_redirected_to account_path
    assert_match "bia.nova@example.com já está em uso", flash[:alert]
    assert_equal "bia@example.com", user.reload.email_address
  end

  test "new shows the resend form" do
    get new_email_confirmation_path

    assert_response :success
    assert_select "form[action=?] input[type=email][name=email_address]", email_confirmations_path
  end

  test "create resends the link to an unconfirmed account" do
    assert_enqueued_email_with EmailConfirmationsMailer, :confirm, args: [ @user ] do
      post email_confirmations_path, params: { email_address: " Ana@Example.com " }
    end

    assert_redirected_to new_session_path
    assert_match "Se existir uma conta não confirmada", flash[:notice]
  end

  test "create gives the same answer for unknown or confirmed addresses without sending anything" do
    create_user(email_address: "bia@example.com")

    assert_no_enqueued_emails do
      post email_confirmations_path, params: { email_address: "ninguem@example.com" }
      post email_confirmations_path, params: { email_address: "bia@example.com" }
    end

    assert_redirected_to new_session_path
    assert_match "Se existir uma conta não confirmada", flash[:notice]
  end

  test "signed-in users resend to their own address" do
    sign_in_as @user

    assert_enqueued_email_with EmailConfirmationsMailer, :confirm, args: [ @user ] do
      post email_confirmations_path, headers: { "Referer" => saved_searches_url }
    end

    assert_redirected_to saved_searches_url
    assert_match "novo link de confirmação para ana@example.com", flash[:notice]
  end

  test "create is rate limited" do
    10.times { post email_confirmations_path, params: { email_address: "ninguem@example.com" } }

    assert_no_enqueued_emails do
      post email_confirmations_path, params: { email_address: "ana@example.com" }
    end

    assert_redirected_to new_email_confirmation_path
    assert_match "Muitas tentativas", flash[:alert]
  end

  test "unconfirmed users see a banner with a resend button" do
    sign_in_as @user

    get saved_searches_path

    assert_select "#email-confirmation-banner", /Confirme o seu e-mail \(ana@example.com\)/ do
      assert_select "form[action=?] button", email_confirmations_path, text: "Reenviar e-mail de confirmação"
    end
  end

  test "confirmed users and visitors see no banner" do
    get root_path
    assert_select "#email-confirmation-banner", count: 0

    sign_in_as create_user
    get saved_searches_path
    assert_select "#email-confirmation-banner", count: 0
  end
end
