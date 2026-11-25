class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_registration_path, alert: "Muitas tentativas. Aguarde alguns minutos e tente de novo." }

  def new
    return redirect_to(root_path) if authenticated?

    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      EmailConfirmationsMailer.confirm(@user).deliver_later
      start_new_session_for @user
      redirect_to after_authentication_url,
                  notice: "Conta criada! Enviamos um link para #{@user.email_address}: confirme o e-mail para receber os alertas."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def registration_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
