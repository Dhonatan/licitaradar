# Refreshes the tenders still open for proposals (see Tenders::Sync).
# Scheduled every few hours; can also be run by hand with `bin/rails pncp:sync`.
#
# The PNCP client already retries each HTTP request a few times. When a whole modality
# still fails (the API is down for a while), the job enqueues itself again for just the
# failed modalities, after RETRY_DELAYS. When the last attempt fails too, it reports the
# error (Rails.error) and e-mails ADMIN_EMAIL, if set (AdminMailer#sync_failed).
class SyncOpenTendersJob < ApplicationJob
  MAX_ATTEMPTS = 3
  # Wait before attempt 2 and attempt 3.
  RETRY_DELAYS = [ 15.minutes, 45.minutes ].freeze

  # Raised (reported, not thrown) when modalities fail on the last attempt.
  class SyncFailed < StandardError; end

  queue_as :default

  # modality_ids: optional list of PNCP modality ids (defaults to the competitive ones).
  # attempt: 1 for the scheduled run; retries pass the next number.
  def perform(modality_ids = nil, attempt = 1)
    options = modality_ids.present? ? { modality_ids: modality_ids } : {}
    runs = Tenders::Sync.call(attempt: attempt, **options).compact

    failed = runs.select(&:failed?)
    handle_failures(failed, attempt) if failed.any?
    runs
  end

  private
    def handle_failures(failed, attempt)
      if attempt < MAX_ATTEMPTS
        wait = RETRY_DELAYS.fetch(attempt - 1, RETRY_DELAYS.last)
        logger.warn "PNCP sync failed for modalities #{failed.map(&:modality_id).join(", ")}; retrying in #{wait.inspect}"
        self.class.set(wait: wait).perform_later(failed.map(&:modality_id), attempt + 1)
      else
        alert(failed, attempt)
      end
    end

    def alert(failed, attempt)
      summary = failed.map { |run| "#{run.modality_id} (#{run.error_message})" }.join("; ")
      Rails.error.report(SyncFailed.new("PNCP sync failed after #{attempt} attempts: #{summary}"),
                         handled: true, context: { modality_ids: failed.map(&:modality_id), attempt: attempt })
      AdminMailer.sync_failed(failed).deliver_now if AdminMailer.recipients.any?
    rescue StandardError => error
      # Alerting must never turn a handled failure into a job crash.
      Rails.error.report(error, handled: true)
    end
end
