class EmailConfirmationsMailer < ApplicationMailer
  # Sent on sign-up, on e-mail changes (to the new address) and from the resend page.
  def confirm(user)
    @user = user
    @email_change = user.unconfirmed_email.present?
    @expires_in_days = (User::CONFIRMATION_EXPIRES_IN / 1.day).round
    @confirmation_url = email_confirmation_url(user.generate_token_for(:email_confirmation))

    mail subject: "Confirme o seu e-mail no LicitaRadar", to: user.email_address_to_confirm
  end
end
