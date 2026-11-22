require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "recipients come from ADMIN_EMAIL" do
    with_env("ADMIN_EMAIL" => " ops@example.com,, dev@example.com ") do
      assert_equal [ "ops@example.com", "dev@example.com" ], AdminMailer.recipients
    end

    with_env("ADMIN_EMAIL" => nil) do
      assert_empty AdminMailer.recipients
    end
  end

  test "sync_failed lists every failed modality with its error" do
    SyncRun.create!(modality_id: 8, started_at: 1.day.ago, status: :failed)
    runs = [
      SyncRun.create!(modality_id: 6, started_at: Time.zone.local(2026, 11, 22, 6, 30), status: :failed, attempt: 3,
                      finished_at: Time.zone.local(2026, 11, 22, 6, 31), error_message: "Pncp::HttpError: PNCP answered HTTP 503"),
      SyncRun.create!(modality_id: 8, started_at: Time.zone.local(2026, 11, 22, 6, 31), status: :failed, attempt: 3,
                      finished_at: Time.zone.local(2026, 11, 22, 6, 32), error_message: nil)
    ]

    mail = with_env("ADMIN_EMAIL" => "ops@example.com") { AdminMailer.sync_failed(runs).message }

    assert_equal [ "ops@example.com" ], mail.to
    assert_equal "[LicitaRadar] Falha na sincronização com o PNCP (2 modalidades)", mail.subject
    body = mail.body.to_s
    assert_match "Pregão - Eletrônico (código 6), tentativa 3, iniciada em 22/11/2026 06:30", body
    assert_match "Erro: Pncp::HttpError: PNCP answered HTTP 503", body
    assert_match "Erro: sem mensagem", body
    assert_match "Falhas seguidas: 2", body
    assert_match "http://example.com/status", body
  end
end
