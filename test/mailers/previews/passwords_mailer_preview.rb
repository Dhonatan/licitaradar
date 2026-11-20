# Preview at http://localhost:3000/rails/mailers/passwords_mailer/reset
class PasswordsMailerPreview < ActionMailer::Preview
  def reset
    PasswordsMailer.reset(User.take || User.new(email_address: "pessoa@example.com", password: "senha-secreta-123"))
  end
end
