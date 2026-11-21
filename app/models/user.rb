# An account. Signs in with e-mail + password (see the Authentication concern); the
# password reset token comes from has_secure_password and expires in 15 minutes.
class User < ApplicationRecord
  MIN_PASSWORD_LENGTH = 8

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :saved_searches, dependent: :destroy
  has_many :api_tokens, dependent: :delete_all

  # Signed token for the "stop every alert" link of the daily digest (see UnsubscribesController).
  generates_token_for :digest_unsubscribe_all

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, length: { maximum: 254 },
                            format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true
end
