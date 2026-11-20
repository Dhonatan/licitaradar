class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Muitas tentativas de login. Aguarde alguns minutos e tente de novo." }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Bem-vindo de volta!"
    else
      redirect_to new_session_path, alert: "E-mail ou senha incorretos."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Você saiu da sua conta.", status: :see_other
  end
end
