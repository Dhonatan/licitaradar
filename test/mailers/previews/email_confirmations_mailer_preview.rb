# Preview at http://localhost:3000/rails/mailers/email_confirmations_mailer
class EmailConfirmationsMailerPreview < ActionMailer::Preview
  def confirm
    EmailConfirmationsMailer.confirm(user)
  end

  def confirm_email_change
    EmailConfirmationsMailer.confirm(user.tap { |record| record.unconfirmed_email = "novo-endereco@example.com" })
  end

  private
    def user
      User.take || User.new(email_address: "pessoa@example.com", password: "senha-secreta-123")
    end
end
