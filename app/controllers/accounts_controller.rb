# "Minha conta": the account's e-mail, its confirmation status and the e-mail change form.
# A new address only replaces the current one after it is confirmed (see User#change_email_to).
class AccountsController < ApplicationController
  before_action :set_user
  rate_limit to: 10, within: 3.minutes, only: :update,
             with: -> { redirect_to account_path, alert: "Muitas tentativas. Aguarde alguns minutos e tente de novo." }

  def show
  end

  def update
    @new_email_address = params[:new_email_address].to_s.strip

    if !@user.authenticate_password(params[:current_password].to_s)
      @user.errors.add(:base, "A senha atual está incorreta.")
    elsif @new_email_address.blank?
      @user.errors.add(:unconfirmed_email, :blank)
    else
      @user.change_email_to(@new_email_address)
      return email_change_saved if @user.save
    end

    render :show, status: :unprocessable_content
  end

  private
    def set_user
      @user = Current.user
    end

    def email_change_saved
      if @user.unconfirmed_email.present?
        EmailConfirmationsMailer.confirm(@user).deliver_later
        redirect_to account_path, notice: "Enviamos um link para #{@user.unconfirmed_email}. O e-mail da conta só muda depois da confirmação."
      else
        redirect_to account_path, notice: "Você continua usando #{@user.email_address}."
      end
    end
end
