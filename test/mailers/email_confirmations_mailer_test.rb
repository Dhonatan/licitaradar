require "test_helper"

class EmailConfirmationsMailerTest < ActionMailer::TestCase
  test "confirm sends the confirmation link to a new account" do
    user = create_user(email_address: "ana@example.com", confirmed: false)

    mail = EmailConfirmationsMailer.confirm(user)

    assert_equal [ "ana@example.com" ], mail.to
    assert_equal "Confirme o seu e-mail no LicitaRadar", mail.subject
    assert_match %r{http://example\.com/email_confirmations/[^/\s"]+}, mail.html_part.body.to_s
    assert_match "3 dias", mail.text_part.body.to_s

    token = mail.text_part.body.to_s[%r{/email_confirmations/(\S+)}, 1]
    assert_equal user, User.find_by_token_for(:email_confirmation, token)
  end

  test "confirm goes to the new address of an e-mail change" do
    user = create_user(email_address: "ana@example.com")
    user.update!(unconfirmed_email: "ana.nova@example.com")

    mail = EmailConfirmationsMailer.confirm(user)

    assert_equal [ "ana.nova@example.com" ], mail.to
    assert_match "trocar o e-mail", mail.text_part.body.to_s
  end
end
