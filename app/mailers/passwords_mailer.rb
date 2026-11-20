class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @expires_in_minutes = (user.password_reset_token_expires_in / 1.minute).round
    mail subject: "Crie uma nova senha no LicitaRadar", to: user.email_address
  end
end
