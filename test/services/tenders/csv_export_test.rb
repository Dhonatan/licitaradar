require "test_helper"

module Tenders
  class CsvExportTest < ActiveSupport::TestCase
    # URL helpers, like the controller provides.
    class Urls
      include Rails.application.routes.url_helpers

      def default_url_options
        { host: "licitaradar.example.com", protocol: "https" }
      end
    end

    def export(records, **options)
      CsvExport.new(records, urls: Urls.new, **options)
    end

    def rows(csv)
      CSV.parse(csv.delete_prefix(CsvExport::BOM), col_sep: ";")
    end

    test "starts with a BOM and the header, then one row per tender, for Excel in Portuguese" do
      tender = create_open_tender(object_description: "Aquisição de material de expediente", agency_name: "Prefeitura de Exemplópolis",
                                  city: "Exemplópolis", state: "PE", estimated_value: 1_234_567.5, purchase_number: "90012", year: 2026,
                                  proposals_close_at: Time.zone.parse("2026-12-02 14:00"), pncp_url: "https://pncp.gov.br/app/editais/00000000000191/2026/12")

      csv = export(Tender.where(id: tender.id).order(:id)).to_a.join

      assert csv.start_with?("﻿Objeto;Órgão;CNPJ do órgão;")
      assert_equal Encoding::UTF_8, csv.encoding
      assert_includes csv, "\r\n"
      header, row = rows(csv)
      values = header.zip(row).to_h
      assert_equal "Aquisição de material de expediente", values["Objeto"]
      assert_equal "Prefeitura de Exemplópolis", values["Órgão"]
      assert_equal "Exemplópolis", values["Município"]
      assert_equal "PE", values["UF"]
      assert_equal "Pregão - Eletrônico", values["Modalidade"]
      assert_equal "1234567,50", values["Valor estimado (R$)"]
      assert_equal "02/12/2026 14:00", values["Encerramento das propostas"]
      assert_equal "90012/2026", values["Número da compra"]
      assert_equal "https://licitaradar.example.com/tenders/#{tender.id}", values["Página no LicitaRadar"]
      assert_equal "https://pncp.gov.br/app/editais/00000000000191/2026/12", values["Edital no PNCP"]
      assert_not_includes header, "Nota"
    end

    test "confidential values, missing data and non-http links" do
      tender = create_open_tender(estimated_value: 0, unit_name: nil, pncp_url: "javascript:alert(1)")

      values = rows(export(Tender.where(id: tender.id)).to_a.join).then { |header, row| header.zip(row).to_h }

      assert_equal "sigiloso", values["Valor estimado (R$)"]
      assert_nil values["Unidade compradora"]
      assert_nil values["Edital no PNCP"]
    end

    test "cells that would start a formula are neutralized" do
      tender = create_open_tender(object_description: "=HYPERLINK(\"http://example.com\")", agency_name: "+55 Prefeitura", process_number: "-1")

      values = rows(export(Tender.where(id: tender.id)).to_a.join).then { |header, row| header.zip(row).to_h }

      assert_equal "'=HYPERLINK(\"http://example.com\")", values["Objeto"]
      assert_equal "'+55 Prefeitura", values["Órgão"]
      assert_equal "'-1", values["Processo"]
    end

    test "keeps the relation's order across batches and stops at the limit" do
      tenders = Array.new(5) { |index| create_open_tender(object_description: "Licitação #{index}", proposals_close_at: (10 - index).days.from_now) }
      queries = 0
      counter = ->(*, payload) { queries += 1 if payload[:sql].include?("FROM \"tenders\"") }

      csv = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        export(Tender.order(:proposals_close_at), batch_size: 2, limit: 4).to_a.join
      end

      assert_equal tenders.reverse.first(4).map(&:object_description), rows(csv).drop(1).map(&:first)
      assert_equal 2, queries
    end

    test "rows are generated lazily, while the export is read" do
      create_open_tender
      chunks = export(Tender.all).each

      assert_kind_of Enumerator, chunks
      assert chunks.next.start_with?(CsvExport::BOM)
      assert_includes chunks.next, "Aquisição de material de expediente"
    end

    test "watches come with their notes" do
      user = create_user
      watch = Watch.watch!(user, create_open_tender(object_description: "Serviço de buffet"))
      watch.update!(note: "Ligar para o pregoeiro\nLevar amostras")

      header, row = rows(export(user.watches.by_deadline, notes: true).to_a.join)

      assert_equal "Nota", header.last
      assert_equal "Serviço de buffet", row.first
      assert_equal "Ligar para o pregoeiro\nLevar amostras", row.last
    end

    test "the search's ordered scope exports every match, not one page" do
      30.times { |index| create_open_tender(object_description: "Serviço de buffet #{index}") }
      search = Search.new(q: "buffet")

      assert_equal 31, rows(export(search.ordered_scope).to_a.join).size
    end
  end
end
