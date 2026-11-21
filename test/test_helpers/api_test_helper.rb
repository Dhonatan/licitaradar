# Request helpers for the JSON API tests.
module ApiTestHelper
  def api_token_for(user, name: "Testes")
    user.api_tokens.create!(name: name).token
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
