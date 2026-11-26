require "test_helper"

class FetchTenderDetailsJobTest < ActiveJob::TestCase
  test "fetches the details of a stale tender" do
    tender = create_fetchable_tender
    stub_tender_details(tender)

    FetchTenderDetailsJob.perform_now(tender)

    assert_equal 3, tender.items.count
    assert tender.reload.details_fetched?
  end

  test "skips tenders that are already current" do
    tender = create_fetchable_tender(details_fetched_at: 1.hour.ago)
    tender.update!(details_source_updated_at: tender.source_updated_at)

    FetchTenderDetailsJob.perform_now(tender)

    assert_not_requested :get, %r{pncp.gov.br/api/pncp}
  end

  test "client errors are reported and not retried" do
    tender = create_fetchable_tender
    stub_tender_details(tender, status: 404)

    assert_error_reported(Pncp::HttpError) do
      assert_no_enqueued_jobs(only: FetchTenderDetailsJob) { FetchTenderDetailsJob.perform_now(tender) }
    end
    assert_not tender.reload.details_fetched?
  end

  test "other PNCP errors are retried later" do
    tender = create_fetchable_tender
    # Raised by the transport, so the client gives up at once (no backoff sleeps).
    stub_request(:get, "#{pncp_purchase_url(tender)}/arquivos").to_raise(Pncp::Error.new("PNCP fora do ar"))

    assert_enqueued_with(job: FetchTenderDetailsJob, args: [ tender ]) { FetchTenderDetailsJob.perform_now(tender) }
    assert_not tender.reload.details_fetched?
  end

  test "is discarded when the tender was deleted" do
    tender = create_fetchable_tender
    FetchTenderDetailsJob.perform_later(tender)
    tender.delete

    assert_nothing_raised { perform_enqueued_jobs }
  end
end
