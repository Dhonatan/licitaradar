require "test_helper"

class SystemStatusTest < ActiveSupport::TestCase
  def run_for(modality_id, status:, started_at:)
    finished_at = started_at + 1.minute unless status == :running
    SyncRun.create!(modality_id: modality_id, status: status, started_at: started_at, finished_at: finished_at)
  end

  test "is healthy when every competitive modality succeeded recently" do
    Pncp::Modalities::COMPETITIVE.each { |id| run_for(id, status: :succeeded, started_at: 2.hours.ago) }

    assert SystemStatus.new.healthy?
  end

  test "a modality is unhealthy when its latest run failed, even after a recent success" do
    run_for(6, status: :succeeded, started_at: 2.hours.ago)
    run_for(6, status: :failed, started_at: 1.hour.ago)

    modality = SystemStatus.new.modalities.find { |item| item.modality_id == 6 }

    assert_not modality.healthy?
    assert_equal 1, modality.failures_in_a_row
    assert modality.latest_run.failed?
  end

  test "a modality is unhealthy when its last success is too old or never happened" do
    run_for(6, status: :succeeded, started_at: 13.hours.ago)

    status = SystemStatus.new
    six, eight = status.modalities.values_at(2, 4)

    assert_equal [ 6, 8 ], [ six.modality_id, eight.modality_id ]
    assert_not six.healthy?
    assert_not eight.healthy?
    assert_nil eight.latest_run
    assert_not status.healthy?
  end

  test "a running sync keeps the modality healthy while the last success is recent" do
    run_for(6, status: :succeeded, started_at: 6.hours.ago)
    run_for(6, status: :running, started_at: 1.minute.ago)

    assert SystemStatus.new.modalities.find { |item| item.modality_id == 6 }.healthy?
  end

  test "lists other synced modalities after the competitive ones" do
    run_for(9, status: :succeeded, started_at: 1.hour.ago)

    assert_equal Pncp::Modalities::COMPETITIVE + [ 9 ], SystemStatus.new.modalities.map(&:modality_id)
  end

  test "counts records of the last 24 hours" do
    create_open_tender
    create_open_tender(created_at: 2.days.ago)
    user = create_user
    saved_search = user.saved_searches.create!(name: "Eventos", query: "eventos")
    Notification.create!(saved_search: saved_search, tender: Tender.first, sent_at: 1.hour.ago)

    counts = SystemStatus.new.counts

    assert_equal 2, counts[:tenders]
    assert_equal 1, counts[:new_tenders_last_24h]
    assert_equal 1, counts[:notifiable_saved_searches]
    assert_equal 1, counts[:notifications_last_24h]
  end
end
