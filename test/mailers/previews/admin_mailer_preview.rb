# Preview at http://localhost:3000/rails/mailers/admin_mailer/sync_failed
class AdminMailerPreview < ActionMailer::Preview
  def sync_failed
    runs = SyncRun.failed.recent.limit(3).to_a.presence ||
           [ SyncRun.new(modality_id: 6, started_at: Time.current, status: :failed, attempt: 3, error_message: "Pncp::HttpError: PNCP answered HTTP 503") ]
    AdminMailer.sync_failed(runs)
  end
end
