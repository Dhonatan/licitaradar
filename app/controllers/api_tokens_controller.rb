# Lets a signed-in user create and revoke the bearer tokens of the JSON API (docs/API.md).
class ApiTokensController < ApplicationController
  def index
    @api_tokens = Current.user.api_tokens.newest_first
    @api_token = Current.user.api_tokens.new
  end

  # Renders the list with the new token instead of redirecting: the token is shown this
  # one time and must not end up in the session cookie (flash) or in a cache.
  def create
    @api_token = Current.user.api_tokens.new(params.expect(api_token: [ :name ]))
    response.headers["Cache-Control"] = "no-store"

    if @api_token.save
      @api_tokens = Current.user.api_tokens.newest_first
      @created_token = @api_token
      @api_token = Current.user.api_tokens.new
      render :index, status: :created
    else
      @api_tokens = Current.user.api_tokens.newest_first
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    api_token = Current.user.api_tokens.find(params[:id])
    api_token.destroy
    redirect_to api_tokens_path, notice: "Token “#{api_token.name}” revogado.", status: :see_other
  end
end
