# Bearer token for the JSON API (`Authorization: Bearer lr_...`). Only a SHA-256 digest is
# stored: the token itself is available in #token right after creation and never again.
#
#   api_token = user.api_tokens.create!(name: "Portal")
#   api_token.token                          # => "lr_..." (show it once)
#   ApiToken.authenticate("lr_...")          # => api_token (and marks it as used)
class ApiToken < ApplicationRecord
  PREFIX = "lr_"
  MAX_PER_USER = 10
  MAX_NAME_LENGTH = 60
  # last_used_at is written at most once per interval, so busy clients don't write on every request.
  LAST_USED_INTERVAL = 1.minute

  belongs_to :user

  attr_reader :token

  normalizes :name, with: ->(name) { name.squish }

  before_validation :generate_token, on: :create

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :token_digest, presence: true, uniqueness: true
  validate :api_tokens_per_user_limit, on: :create

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # The ApiToken for a plain token, or nil. Marks it as used.
  def self.authenticate(token, now: Time.current)
    return unless token.is_a?(String) && token.start_with?(PREFIX)

    find_by(token_digest: digest(token))&.tap { |api_token| api_token.mark_as_used(now) }
  end

  def mark_as_used(now = Time.current)
    update_column(:last_used_at, now) if last_used_at.nil? || last_used_at <= now - LAST_USED_INTERVAL
  end

  private
    def generate_token
      @token = "#{PREFIX}#{SecureRandom.base58(40)}"
      self.token_digest = self.class.digest(@token)
      self.token_hint = @token.first(PREFIX.length + 4)
    end

    def api_tokens_per_user_limit
      return unless user && user.api_tokens.count >= MAX_PER_USER

      errors.add(:base, "Você já tem #{MAX_PER_USER} tokens, o máximo por conta. Revogue um para criar outro.")
    end
end
