require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset sends a link to the new password page" do
    user = create_user(email_address: "ana@example.com")

    mail = PasswordsMailer.reset(user)

    assert_equal [ "ana@example.com" ], mail.to
    assert_equal "Crie uma nova senha no LicitaRadar", mail.subject
    assert_match %r{http://example\.com/passwords/[^/\s"]+/edit}, mail.html_part.body.to_s
    assert_match %r{http://example\.com/passwords/[^/\s"]+/edit}, mail.text_part.body.to_s
    assert_match "15 minutos", mail.text_part.body.to_s
  end
end
