require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def create_tender(number, **attributes)
    Tender.create!({
      pncp_control_number: "00000000000191-1-#{number.to_s.rjust(6, "0")}/2026",
      modality_id: 6,
      status_id: Tender::PUBLISHED_STATUS_ID,
      proposals_close_at: 20.days.from_now
    }.merge(attributes))
  end

  test "home explains the product and lists tracked modalities" do
    get root_path

    assert_response :success
    assert_select "h1", /Licitações abertas para o seu nicho/
    assert_select ".modalities li", Pncp::Modalities::COMPETITIVE.size
  end

  test "home is the search entry point with niche shortcuts" do
    get root_path

    assert_select "form[action=?][method=get] input[type=search][name=q]", tenders_path
    Niche.all.each do |niche|
      assert_select ".niche-shortcuts a[href=?]", tenders_path(niche: niche.slug), text: niche.name
    end
  end

  test "home shows open tenders, closing this week and last sync" do
    create_tender(1)
    create_tender(2, proposals_close_at: 3.days.from_now)
    create_tender(3, proposals_close_at: 1.day.ago)
    SyncRun.create!(modality_id: 6, status: "succeeded", started_at: Time.zone.local(2026, 11, 19, 6, 0), finished_at: Time.zone.local(2026, 11, 19, 6, 5))

    get root_path

    assert_select "#stat-open .stat__value", "2"
    assert_select "#stat-closing .stat__value a[href=?]", tenders_path(closing_within: 7), text: "1"
    assert_select "#stat-sync .stat__value", "19/11/2026 às 06:05"
  end

  test "home says when nothing was synced yet" do
    get root_path

    assert_select "#stat-open .stat__value", "0"
    assert_select "#stat-sync .stat__label", /ainda não sincronizado/
  end

  test "home counters are cached for 5 minutes" do
    create_tender(1)
    get root_path
    assert_select "#stat-open .stat__value", "1"

    create_tender(2)
    SyncRun.create!(modality_id: 6, status: "succeeded", started_at: 1.minute.ago, finished_at: Time.current)
    get root_path
    assert_select "#stat-open .stat__value", "1"
    assert_select "#stat-sync .stat__label", /ainda não sincronizado/

    travel 5.minutes + 1.second do
      get root_path
    end
    assert_select "#stat-open .stat__value", "2"
    assert_select "#stat-sync .stat__label", /última sincronização/
  end

  test "health check responds" do
    get rails_health_check_path

    assert_response :success
  end
end
