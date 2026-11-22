require "test_helper"

class StatusControllerTest < ActionDispatch::IntegrationTest
  CREDENTIALS = { "STATUS_USERNAME" => "admin", "STATUS_PASSWORD" => "senha-do-status" }.freeze

  def basic_auth(username = "admin", password = "senha-do-status")
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
  end

  def record_success(modality_id, at: 1.hour.ago)
    SyncRun.create!(modality_id: modality_id, started_at: at, finished_at: at + 1.minute, status: :succeeded,
                    pages: 1, fetched_count: 10, upserted_count: 10)
  end

  test "does not exist when no credentials are configured" do
    with_env("STATUS_USERNAME" => nil, "STATUS_PASSWORD" => nil) do
      get status_path, headers: basic_auth
    end

    assert_response :not_found
  end

  test "asks for credentials" do
    with_env(CREDENTIALS) { get status_path }

    assert_response :unauthorized
    assert_match "Basic", response.headers["WWW-Authenticate"]
  end

  test "rejects wrong credentials" do
    with_env(CREDENTIALS) { get status_path, headers: basic_auth("admin", "errada") }

    assert_response :unauthorized
  end

  test "shows the sync of every modality, counts and jobs" do
    Pncp::Modalities::COMPETITIVE.each { |id| record_success(id) }
    SyncRun.create!(modality_id: 8, started_at: 10.minutes.ago, finished_at: 9.minutes.ago, status: :failed,
                    attempt: 2, error_message: "Pncp::HttpError: PNCP answered HTTP 503")
    create_open_tender
    create_user

    with_env(CREDENTIALS) { get status_path, headers: basic_auth }

    assert_response :success
    assert_select "#overall-status", "atenção"
    assert_select "#modality-6 .badge", "ok"
    assert_select "#modality-8 .badge", "atenção"
    assert_select "#modality-8", /HTTP 503/
    assert_select "#count-open-tenders .stat__value", "1"
    assert_select "#count-users .stat__value", "1"
    assert_select "#jobs-failed .stat__value", "0"
    assert_select "#recent-runs tbody tr", Pncp::Modalities::COMPETITIVE.size + 1
  end

  test "works before the first sync" do
    with_env(CREDENTIALS) { get status_path, headers: basic_auth }

    assert_response :success
    assert_select "#modality-6 .badge", "nunca sincronizada"
    assert_select "#recent-runs", false
  end

  test "JSON answers 200 when healthy" do
    Pncp::Modalities::COMPETITIVE.each { |id| record_success(id) }

    with_env(CREDENTIALS) { get status_path(format: :json), headers: basic_auth }

    assert_response :success
    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal Pncp::Modalities::COMPETITIVE, body["modalities"].map { |modality| modality["id"] }
    assert body["modalities"].all? { |modality| modality["healthy"] }
    assert_equal 0, body.dig("counts", "tenders")
    assert_equal 0, body.dig("jobs", "failed")
  end

  test "JSON answers 503 when the sync is stale" do
    Pncp::Modalities::COMPETITIVE.each { |id| record_success(id, at: 13.hours.ago) }

    with_env(CREDENTIALS) { get status_path(format: :json), headers: basic_auth }

    assert_response :service_unavailable
    assert_equal "degraded", response.parsed_body["status"]
  end
end
