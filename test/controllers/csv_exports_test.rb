require "test_helper"

class CsvExportsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  def csv_rows
    CSV.parse(response.body.delete_prefix(Tenders::CsvExport::BOM), col_sep: ";")
  end

  test "the results page links to the CSV of the same search" do
    create_open_tender(object_description: "Serviço de buffet")

    get tenders_path(q: "buffet", states: [ "PE" ])

    assert_select "a.export-csv[href=?][data-turbo=false]", tenders_path(q: "buffet", states: [ "PE" ], format: :csv), text: "Exportar CSV"
  end

  test "no export link without results" do
    get tenders_path(q: "inexistente")

    assert_select "a.export-csv", 0
  end

  test "exporting requires login and comes back to the download" do
    get tenders_path(q: "buffet", format: :csv)
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: RecordsTestHelper::DEFAULT_PASSWORD }
    assert_redirected_to tenders_url(q: "buffet", format: :csv)
  end

  test "streams the search results as a CSV download" do
    buffet = create_open_tender(object_description: "Serviço de buffet", proposals_close_at: 2.days.from_now)
    create_open_tender(object_description: "Serviço de buffet infantil", proposals_close_at: 5.days.from_now)
    create_open_tender(object_description: "Aquisição de pneus")
    create_open_tender(object_description: "Serviço de buffet encerrado", proposals_close_at: 1.day.ago)
    sign_in_as @user

    get tenders_path(q: "buffet", sort: "closing", format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/\Aattachment; filename="licitacoes-abertas-\d{4}-\d{2}-\d{2}\.csv"/, response.headers["Content-Disposition"])
    assert_equal "no", response.headers["X-Accel-Buffering"]
    assert response.body.start_with?("﻿")
    rows = csv_rows
    assert_equal "Objeto", rows.first.first
    assert_equal [ "Serviço de buffet", "Serviço de buffet infantil" ], rows.drop(1).map(&:first)
    assert_includes rows[1], "http://www.example.com/tenders/#{buffet.id}"
  end

  test "exports are rate limited per user" do
    sign_in_as @user

    20.times { get tenders_path(format: :csv) }
    assert_response :success

    get tenders_path(format: :csv)
    assert_redirected_to tenders_path
    assert_match(/Muitas exportações/, flash[:alert])
  end

  test "the watchlist exports the watched tenders with notes" do
    soon = create_open_tender(object_description: "Locação de palco", proposals_close_at: 1.day.from_now)
    closed = create_open_tender(object_description: "Aquisição de pneus", proposals_close_at: 3.days.ago)
    Watch.watch!(@user, closed)
    Watch.watch!(@user, soon).update!(note: "Levar amostras")
    Watch.watch!(create_user, create_open_tender(object_description: "De outra pessoa"))
    sign_in_as @user

    get watches_path
    assert_select "a[href=?][data-turbo=false]", watches_path(format: :csv), text: "Exportar CSV"

    get watches_path(format: :csv)

    assert_response :success
    assert_match(/filename="minhas-licitacoes-/, response.headers["Content-Disposition"])
    rows = csv_rows
    assert_equal "Nota", rows.first.last
    assert_equal [ "Locação de palco", "Aquisição de pneus" ], rows.drop(1).map(&:first)
    assert_equal "Levar amostras", rows[1].last
  end

  test "the watchlist export requires login" do
    get watches_path(format: :csv)

    assert_redirected_to new_session_path
  end
end
