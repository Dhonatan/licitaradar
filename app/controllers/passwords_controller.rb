class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_password_path, alert: "Muitas tentativas. Aguarde alguns minutos e tente de novo." }

  def new
  end

  # Same answer whether or not the address has an account, so this form can't be used
  # to find out who is registered.
  def create
    if (user = User.find_by(email_address: params[:email_address].to_s.strip.downcase))
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Se existir uma conta com esse e-mail, enviamos as instruções para criar uma nova senha."
  end

  def edit
  end

  def update
    password_params = params.permit(:password, :password_confirmation)

    # has_secure_password ignores a blank password on update, so check it here.
    if password_params[:password].present? && @user.update(password_params)
      # The reset link reached the account's address, which proves the user owns it.
      @user.update!(confirmed_at: Time.current) unless @user.confirmed?
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Senha alterada. Entre com a nova senha."
    else
      @user.errors.add(:password, :blank) if password_params[:password].blank?
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "O link para criar uma nova senha é inválido ou expirou. Peça outro."
    end
end
