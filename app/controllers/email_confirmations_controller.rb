# Confirmation links (GET /email_confirmations/:token) and the "resend the confirmation
# e-mail" page. Signed-in users resend for their own account; signed-out visitors type the
# address and always get the same answer, so the form does not reveal who is registered.
class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_email_confirmation_path, alert: "Muitas tentativas. Aguarde alguns minutos e tente de novo." }

  def new
  end

  def create
    if authenticated?
      send_confirmation_to Current.user
      redirect_back_or_to root_path, notice: "Enviamos um novo link de confirmação para #{Current.user.email_address_to_confirm}."
    else
      user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
      send_confirmation_to user if user && !user.confirmed?
      redirect_to new_session_path, notice: "Se existir uma conta não confirmada com esse e-mail, enviamos um novo link de confirmação."
    end
  end

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])
    return redirect_to(new_email_confirmation_path, alert: "O link de confirmação é inválido ou expirou. Peça outro.") unless user

    new_address = user.unconfirmed_email
    if user.confirm_email
      redirect_to next_page(root_path), notice: "E-mail #{user.email_address} confirmado! Os alertas das suas buscas estão ativos."
    else
      redirect_to next_page(account_path), alert: "O e-mail #{new_address} já está em uso por outra conta. Escolha outro endereço."
    end
  end

  private
    def send_confirmation_to(user)
      EmailConfirmationsMailer.confirm(user).deliver_later if user.confirmation_pending?
    end

    # The link may be opened in a browser that is not signed in.
    def next_page(signed_in_path)
      authenticated? ? signed_in_path : new_session_path
    end
end
