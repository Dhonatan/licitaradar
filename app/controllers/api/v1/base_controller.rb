module Api
  module V1
    # Base of the JSON API v1 (see docs/API.md): bearer-token authentication (ApiToken),
    # errors as JSON ({ "error": { "code", "message", "details" } }) and a rate limit per token.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      RATE_LIMIT = 300
      RATE_LIMIT_PERIOD = 5.minutes

      # Request bodies must say what they are ({ "saved_search": { ... } }); no guessing.
      wrap_parameters false

      before_action :authenticate_api_token
      rate_limit to: RATE_LIMIT, within: RATE_LIMIT_PERIOD, by: -> { "api_token:#{@api_token.id}" },
                 with: -> { render_error :too_many_requests, "rate_limited", "Limite de requisições atingido. Tente de novo em alguns minutos." }

      rescue_from ActiveRecord::RecordNotFound do
        render_error :not_found, "not_found", "Registro não encontrado."
      end

      rescue_from ActionController::ParameterMissing, ActionDispatch::Http::Parameters::ParseError do |error|
        render_error :bad_request, "bad_request", "Requisição inválida: #{error.message}"
      end

      private
        attr_reader :api_token

        def current_user
          api_token.user
        end

        # Accepts "Authorization: Bearer <token>" (and Rails' "Token token=<token>").
        def authenticate_api_token
          @api_token = authenticate_with_http_token { |token, _options| ApiToken.authenticate(token) }
          return if @api_token

          response.headers["WWW-Authenticate"] = %(Bearer realm="LicitaRadar")
          render_error :unauthorized, "unauthorized", "Envie um token de API válido no cabeçalho Authorization: Bearer <token>."
        end

        def render_error(status, code, message, details: nil)
          render json: { error: { code: code, message: message, details: details }.compact }, status: status
        end
    end
  end
end
