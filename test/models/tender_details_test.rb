require "test_helper"

class TenderDetailsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "details are fetchable with a 14-digit agency CNPJ, year and sequence" do
    assert create_fetchable_tender.details_fetchable?
    assert_not create_fetchable_tender(sequence: nil).details_fetchable?
    assert_not create_fetchable_tender(agency_cnpj: "123").details_fetchable?
  end

  test "details are stale until fetched and again when the PNCP version changes" do
    tender = create_fetchable_tender
    assert tender.details_stale?

    tender.update!(details_fetched_at: Time.current, details_source_updated_at: tender.source_updated_at)
    assert_not tender.details_stale?

    tender.update!(source_updated_at: tender.source_updated_at + 1.hour)
    assert tender.details_stale?
  end

  test "request_details_fetch enqueues one job per interval" do
    tender = create_fetchable_tender

    assert_enqueued_with(job: FetchTenderDetailsJob, args: [ tender ]) do
      assert tender.request_details_fetch
    end
    assert_not_nil tender.reload.details_requested_at

    assert_no_enqueued_jobs { assert_not Tender.find(tender.id).request_details_fetch }

    travel Tender::DETAILS_REQUEST_INTERVAL + 1.second do
      assert_enqueued_jobs(1, only: FetchTenderDetailsJob) { assert tender.reload.request_details_fetch }
    end
  end

  test "request_details_fetch does nothing for current or unaddressable tenders" do
    current = create_fetchable_tender
    current.update!(details_fetched_at: Time.current, details_source_updated_at: current.source_updated_at)

    assert_no_enqueued_jobs do
      assert_not current.request_details_fetch
      assert_not create_fetchable_tender(year: nil).request_details_fetch
    end
  end

  test "documents and items are ordered and deleted with the tender" do
    tender = create_fetchable_tender
    tender.items.create!(number: 2, description: "Caneta")
    tender.items.create!(number: 1, description: "Papel")
    tender.documents.create!(sequence: 1, title: "Edital")

    assert_equal [ 1, 2 ], tender.items.map(&:number)
    assert_raises(ActiveRecord::RecordInvalid) { tender.items.create!(number: 1) }

    tender.destroy!
    assert_equal 0, TenderItem.count
    assert_equal 0, TenderDocument.count
  end

  test "archiving deletes documents and items through the foreign keys" do
    tender = create_fetchable_tender(proposals_close_at: 1.year.ago)
    tender.items.create!(number: 1, description: "Papel")
    tender.documents.create!(sequence: 1, title: "Edital")

    Tenders::Archive.new.call

    assert_not Tender.exists?(tender.id)
    assert_equal 0, TenderItem.count + TenderDocument.count
  end

  test "items know their kind and whether the value is confidential" do
    item = TenderItem.new(material_or_service: "S", unit_estimated_value: nil, total_estimated_value: nil)

    assert_equal "Serviço", item.kind_name
    assert item.confidential_value?
    assert_not TenderItem.new(total_estimated_value: 10).confidential_value?
  end
end
