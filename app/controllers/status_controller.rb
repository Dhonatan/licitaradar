# Admin status page: sync health per PNCP modality, counts and the job queue.
# Protected by HTTP basic auth with STATUS_USERNAME / STATUS_PASSWORD; when they are not
# set the page does not exist (404). GET /status.json answers 503 when the sync is
# unhealthy, for uptime monitors.
class StatusController < ApplicationController
  allow_unauthenticated_access
  before_action :require_status_credentials

  def show
    @status = SystemStatus.new

    respond_to do |format|
      format.html
      format.json { render json: @status, status: @status.healthy? ? :ok : :service_unavailable }
    end
  end

  private
    def require_status_credentials
      username = ENV["STATUS_USERNAME"].to_s
      password = ENV["STATUS_PASSWORD"].to_s
      # Behave exactly like a route that doesn't exist.
      raise ActionController::RoutingError, "Not Found" if username.empty? || password.empty?

      http_basic_authenticate_or_request_with name: username, password: password, realm: "LicitaRadar status"
    end
end
