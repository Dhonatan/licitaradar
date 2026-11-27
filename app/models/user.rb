# An account. Signs in with e-mail + password (see the Authentication concern); the
# password reset token comes from has_secure_password and expires in 15 minutes.
#
# E-mail confirmation: a new account is unconfirmed (confirmed_at nil) until its owner
# opens the link of EmailConfirmationsMailer; only confirmed accounts get alerts. Changing
# the address stores the new one in unconfirmed_email and keeps the current one (for login
# and alerts) until the new address is confirmed.
class User < ApplicationRecord
  MIN_PASSWORD_LENGTH = 8
  MAX_EMAIL_LENGTH = 254
  CONFIRMATION_EXPIRES_IN = 3.days

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :saved_searches, dependent: :destroy
  has_many :api_tokens, dependent: :delete_all
  has_many :watches, dependent: :delete_all
  has_many :watched_tenders, through: :watches, source: :tender

  # Signed token for the "stop every alert" link of the daily digest (see UnsubscribesController).
  generates_token_for :digest_unsubscribe_all

  # Signed token of the confirmation link. It embeds the addresses, so it stops working
  # once a pending change is confirmed or replaced by another one.
  generates_token_for :email_confirmation, expires_in: CONFIRMATION_EXPIRES_IN do
    [ email_address, unconfirmed_email ]
  end

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :unconfirmed_email, with: ->(email) { email.strip.downcase.presence }

  validates :email_address, presence: true, uniqueness: true, length: { maximum: MAX_EMAIL_LENGTH },
                            format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :unconfirmed_email, length: { maximum: MAX_EMAIL_LENGTH },
                                format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :unconfirmed_email_must_be_available
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true

  scope :confirmed, -> { where.not(confirmed_at: nil) }

  def confirmed?
    confirmed_at.present?
  end

  # True while there is an address waiting for its confirmation link: the account's own
  # (never confirmed) or the new one of a pending e-mail change.
  def confirmation_pending?
    !confirmed? || unconfirmed_email.present?
  end

  # Where the confirmation link goes.
  def email_address_to_confirm
    unconfirmed_email.presence || email_address
  end

  # Starts an e-mail change (save the record and send the confirmation afterwards). Asking
  # for the current address again cancels a pending change.
  def change_email_to(address)
    address = address.to_s.strip.downcase
    self.unconfirmed_email = address == email_address ? nil : address
  end

  # Applies the confirmation link: confirms the account's address or, for an e-mail change,
  # replaces it with the new one. Returns false when the new address was taken meanwhile.
  def confirm_email
    if unconfirmed_email.present?
      update(email_address: unconfirmed_email, unconfirmed_email: nil, confirmed_at: Time.current)
    else
      confirmed? || update(confirmed_at: Time.current)
    end
  end

  private
    def unconfirmed_email_must_be_available
      return if unconfirmed_email.blank? || !will_save_change_to_unconfirmed_email?

      errors.add(:unconfirmed_email, :taken) if User.where.not(id: id).exists?(email_address: unconfirmed_email)
    end
end
