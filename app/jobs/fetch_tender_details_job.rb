# Fetches the documents and items of a tender in the background (Tenders::FetchDetails).
# Enqueued by Tender#request_details_fetch the first time a tender page is opened and
# again after the tender changes on the PNCP.
class FetchTenderDetailsJob < ApplicationJob
  queue_as :default

  # Pncp::Client already retries each request; this covers longer outages.
  retry_on Pncp::Error, wait: 2.minutes, attempts: 3 do |job, error|
    Rails.error.report(error, handled: true, context: { job: job, tender: job.arguments.first })
  end

  # The tender was archived before the job ran.
  discard_on ActiveJob::DeserializationError

  def perform(tender)
    # Another job (or a sync that did not change it) may have made it current meanwhile.
    return unless tender.details_fetchable? && tender.details_stale?

    Tenders::FetchDetails.call(tender)
  rescue Pncp::HttpError => error
    raise if error.retryable?

    # 4xx: retrying will not help. The next page view after DETAILS_REQUEST_INTERVAL tries again.
    Rails.error.report(error, handled: true, context: { job: self, tender: tender })
    nil
  end
end
