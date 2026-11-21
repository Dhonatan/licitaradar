require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  setup do
    @user = create_user
  end

  test "creating a token exposes it once and stores only its digest" do
    api_token = @user.api_tokens.create!(name: "  Integração   CRM ")

    assert_match(/\Alr_[1-9A-HJ-NP-Za-km-z]{40}\z/, api_token.token)
    assert_equal ApiToken.digest(api_token.token), api_token.token_digest
    assert_equal api_token.token.first(7), api_token.token_hint
    assert_equal "Integração CRM", api_token.name
    assert_nil ApiToken.find(api_token.id).token
  end

  test "authenticate finds the token and marks it as used at most once a minute" do
    api_token = @user.api_tokens.create!(name: "Portal")
    now = Time.current.change(usec: 0)

    assert_equal api_token, ApiToken.authenticate(api_token.token, now: now)
    assert_equal now, api_token.reload.last_used_at

    ApiToken.authenticate(api_token.token, now: now + 30.seconds)
    assert_equal now, api_token.reload.last_used_at

    ApiToken.authenticate(api_token.token, now: now + 2.minutes)
    assert_equal now + 2.minutes, api_token.reload.last_used_at
  end

  test "authenticate rejects unknown, malformed and revoked tokens" do
    api_token = @user.api_tokens.create!(name: "Portal")

    assert_nil ApiToken.authenticate(nil)
    assert_nil ApiToken.authenticate("")
    assert_nil ApiToken.authenticate("lr_naoexiste")
    assert_nil ApiToken.authenticate(api_token.token_digest)
    assert_nil ApiToken.authenticate([ api_token.token ])

    api_token.destroy
    assert_nil ApiToken.authenticate(api_token.token)
  end

  test "requires a name and limits tokens per user" do
    assert_not @user.api_tokens.new(name: " ").valid?
    assert_not @user.api_tokens.new(name: "x" * (ApiToken::MAX_NAME_LENGTH + 1)).valid?

    ApiToken::MAX_PER_USER.times { |index| @user.api_tokens.create!(name: "Token #{index}") }
    extra = @user.api_tokens.new(name: "Mais um")

    assert_not extra.valid?
    assert_includes extra.errors[:base], "Você já tem #{ApiToken::MAX_PER_USER} tokens, o máximo por conta. Revogue um para criar outro."
    assert create_user.api_tokens.new(name: "De outra pessoa").valid?
  end

  test "tokens go away with their user" do
    @user.api_tokens.create!(name: "Portal")

    assert_difference -> { ApiToken.count }, -1 do
      @user.destroy
    end
  end
end
