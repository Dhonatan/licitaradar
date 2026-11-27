require "csv"

module Tenders
  # Tenders as CSV for spreadsheets (search results, "Minhas licitações"), generated while
  # it is streamed (see CsvStreaming): the BOM and the header first, then the rows, read
  # from the database in batches, at most MAX_ROWS.
  #
  # Made for Excel in Portuguese: UTF-8 with BOM (accents), ";" between columns, decimal
  # comma and dd/mm/aaaa hh:mm dates in Brasília time. Text cells that would start a
  # formula (=, +, -, @) get a leading apostrophe (CSV injection: object descriptions come
  # from third parties).
  #
  #   export = Tenders::CsvExport.new(search.ordered_scope, urls: controller)
  #   export.each { |chunk| io << chunk }
  #   Tenders::CsvExport.new(user.watches.by_deadline, urls: controller, notes: true)  # watches, with a "Nota" column
  class CsvExport
    include Enumerable

    MAX_ROWS = 5_000
    BATCH_SIZE = 500
    BOM = "﻿".freeze
    COL_SEP = ";".freeze
    FORMULA_START = /\A[=+\-@\t\r]/
    # Columns that are never exported (large or internal).
    SKIPPED_COLUMNS = %w[ raw items_text searchable ].freeze

    HEADERS = [
      "Objeto", "Órgão", "CNPJ do órgão", "Unidade compradora", "Município", "UF", "Modalidade", "Situação",
      "Valor estimado (R$)", "Abertura das propostas", "Encerramento das propostas", "Publicado no PNCP",
      "Número da compra", "Processo", "Nº de controle PNCP", "Página no LicitaRadar", "Edital no PNCP"
    ].freeze

    # records: an ordered relation of Tender, or of Watch with `notes: true`.
    def initialize(records, urls:, notes: false, limit: MAX_ROWS, batch_size: BATCH_SIZE)
      @records = notes ? records.preload(:tender) : records.select(*(Tender.column_names - SKIPPED_COLUMNS).map { |name| Tender.arel_table[name] })
      @urls = urls
      @notes = notes
      @limit = limit
      @batch_size = batch_size
    end

    def each
      return enum_for(:each) unless block_given?

      yield BOM + line(@notes ? HEADERS + [ "Nota" ] : HEADERS)
      each_record do |record|
        yield line(@notes ? tender_values(record.tender) + [ text(record.note) ] : tender_values(record))
      end
    end

    private
      # Offset batches keep the relation's order (find_each would sort by id).
      def each_record(&block)
        offset = 0
        while offset < @limit
          batch = @records.limit([ @batch_size, @limit - offset ].min).offset(offset).to_a
          batch.each(&block)
          break if batch.size < @batch_size

          offset += batch.size
        end
      end

      def line(values)
        CSV.generate_line(values, col_sep: COL_SEP, row_sep: "\r\n")
      end

      def tender_values(tender)
        [
          text(tender.object_description),
          text(tender.agency_name),
          tender.agency_cnpj,
          text(tender.unit_name),
          text(tender.city),
          tender.state,
          text(tender.modality_name.presence || (Pncp::Modalities.name_for(tender.modality_id) if tender.modality_id)),
          text(tender.status_name),
          (tender.confidential_value? ? "sigiloso" : decimal(tender.estimated_value)),
          time(tender.proposals_open_at),
          time(tender.proposals_close_at),
          time(tender.published_at),
          text([ tender.purchase_number, tender.year ].compact_blank.join("/").presence),
          text(tender.process_number),
          tender.pncp_control_number,
          @urls.tender_url(tender),
          http_url(tender.pncp_url)
        ]
      end

      def text(value)
        value = value.to_s.gsub(/\r\n?/, "\n").strip
        return if value.empty?

        value.match?(FORMULA_START) ? "'#{value}" : value
      end

      # 1234.5 => "1234,50" (no thousands separator, so spreadsheets read a number).
      def decimal(value)
        whole, fraction = value.to_d.round(2).to_s("F").split(".")
        "#{whole},#{fraction.to_s.ljust(2, "0")}"
      end

      def time(value)
        value&.in_time_zone&.strftime("%d/%m/%Y %H:%M")
      end

      def http_url(url)
        uri = URI.parse(url.to_s.strip)
        uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
      rescue URI::InvalidURIError
        nil
      end
  end
end
