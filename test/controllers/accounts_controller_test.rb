require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = create_user(email_address: "ana@example.com", password: "senha-secreta")
    sign_in_as @user
  end

  def change_email(address, password: "senha-secreta")
    patch account_path, params: { new_email_address: address, current_password: password }
  end

  test "requires login" do
    sign_out

    get account_path

    assert_redirected_to new_session_path
  end

  test "show lists the e-mail and its status" do
    get account_path

    assert_response :success
    assert_select "#account-email", /ana@example.com/
    assert_select "#account-email .badge", "confirmado"
    assert_select "form[action=?] input[name=new_email_address]", account_path
    assert_select "nav a[href=?]", account_path, text: "Minha conta"
  end

  test "show says when the e-mail is not confirmed" do
    @user.update!(confirmed_at: nil)

    get account_path

    assert_select "#account-email .badge", "não confirmado"
  end

  test "changing the e-mail sends a confirmation to the new address and keeps the current one" do
    assert_enqueued_email_with EmailConfirmationsMailer, :confirm, args: [ @user ] do
      change_email(" Ana.Nova@Example.com ")
    end

    assert_redirected_to account_path
    assert_match "Enviamos um link para ana.nova@example.com", flash[:notice]
    @user.reload
    assert_equal "ana@example.com", @user.email_address
    assert_equal "ana.nova@example.com", @user.unconfirmed_email
    assert @user.confirmed?

    follow_redirect!
    assert_select "#pending-email-change", /ana.nova@example.com/
  end

  test "the new address is only used after the link is opened" do
    change_email("ana.nova@example.com")
    token = @user.reload.generate_token_for(:email_confirmation)

    get email_confirmation_path(token)

    assert_equal "ana.nova@example.com", @user.reload.email_address
    assert User.authenticate_by(email_address: "ana.nova@example.com", password: "senha-secreta")
    assert_nil User.authenticate_by(email_address: "ana@example.com", password: "senha-secreta")
  end

  test "requires the current password" do
    assert_no_enqueued_emails do
      change_email("ana.nova@example.com", password: "errada")
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /A senha atual está incorreta/
    assert_select "input[name=new_email_address][value=?]", "ana.nova@example.com"
    assert_nil @user.reload.unconfirmed_email
  end

  test "rejects a blank, invalid or taken address" do
    create_user(email_address: "bia@example.com")

    change_email("")
    assert_response :unprocessable_content
    assert_select ".form-errors", /Novo e-mail não pode ficar em branco/

    change_email("ana-sem-arroba")
    assert_select ".form-errors", /Novo e-mail não é válido/

    change_email("bia@example.com")
    assert_select ".form-errors", /Novo e-mail já está em uso/

    assert_nil @user.reload.unconfirmed_email
  end

  test "the current address cancels a pending change" do
    @user.update!(unconfirmed_email: "ana.nova@example.com")

    assert_no_enqueued_emails do
      change_email("ana@example.com")
    end

    assert_redirected_to account_path
    assert_nil @user.reload.unconfirmed_email
  end
end
