require "bigdecimal"
require "time"

module Pncp
  # Turns one raw record from the PNCP API (Portuguese field names, Brasília
  # local times, nested agency/unit objects) into a flat hash of attributes
  # that maps 1:1 to the `tenders` table.
  class TenderNormalizer
    BRASILIA_OFFSET = "-03:00".freeze
    PUBLIC_URL = "https://pncp.gov.br/app/editais/%<cnpj>s/%<year>s/%<sequence>s".freeze

    def self.call(record)
      new(record).call
    end

    def initialize(record)
      @record = record || {}
    end

    def call
      control_number = string(@record["numeroControlePNCP"])
      raise InvalidRecord, "record without numeroControlePNCP" unless control_number

      agency = @record["orgaoEntidade"] || {}
      unit = @record["unidadeOrgao"] || {}
      cnpj = digits(agency["cnpj"])
      year = integer(@record["anoCompra"])
      sequence = integer(@record["sequencialCompra"])

      {
        pncp_control_number: control_number,
        year: year,
        sequence: sequence,
        purchase_number: string(@record["numeroCompra"]),
        process_number: string(@record["processo"]),
        modality_id: integer(@record["modalidadeId"]),
        modality_name: string(@record["modalidadeNome"]),
        dispute_mode_name: string(@record["modoDisputaNome"]),
        status_id: integer(@record["situacaoCompraId"]),
        status_name: string(@record["situacaoCompraNome"]),
        object_description: PiiScrubber.call(string(@record["objetoCompra"])),
        additional_info: PiiScrubber.call(string(@record["informacaoComplementar"])),
        price_registration: @record["srp"] == true,
        estimated_value: decimal(@record["valorTotalEstimado"]),
        awarded_value: decimal(@record["valorTotalHomologado"]),
        proposals_open_at: time(@record["dataAberturaProposta"]),
        proposals_close_at: time(@record["dataEncerramentoProposta"]),
        published_at: time(@record["dataPublicacaoPncp"]),
        source_updated_at: time(@record["dataAtualizacao"]),
        agency_cnpj: cnpj,
        agency_name: string(agency["razaoSocial"] || agency["razaosocial"]),
        agency_power: string(agency["poderId"]),
        agency_sphere: string(agency["esferaId"]),
        unit_code: string(unit["codigoUnidade"]),
        unit_name: string(unit["nomeUnidade"]),
        ibge_code: string(unit["codigoIbge"]),
        city: string(unit["municipioNome"]),
        state: string(unit["ufSigla"])&.upcase,
        origin_url: string(@record["linkSistemaOrigem"]),
        pncp_url: public_url(cnpj, year, sequence)
      }
    end

    private
      def string(value)
        return nil if value.nil?

        text = value.to_s.strip
        text.empty? ? nil : text
      end

      def digits(value)
        string(value)&.delete("^0-9")
      end

      def integer(value)
        return value if value.is_a?(Integer)
        return nil if string(value).nil?

        Integer(string(value), 10, exception: false)
      end

      def decimal(value)
        text = string(value)
        return nil unless text

        BigDecimal(text)
      rescue ArgumentError
        nil
      end

      # PNCP sends Brasília local times without an offset ("2026-11-20T09:00:00"),
      # sometimes without seconds, and some fields as plain dates ("2026-11-20").
      def time(value)
        text = string(value)
        return nil unless text&.match?(/\A\d{4}-\d{2}-\d{2}/)

        text = "#{text}T00:00:00" if text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        text = "#{text}:00" if text.match?(/T\d{2}:\d{2}\z/)
        text = "#{text}#{BRASILIA_OFFSET}" unless text.match?(/(Z|[+-]\d{2}:?\d{2})\z/)
        Time.iso8601(text).getlocal(BRASILIA_OFFSET)
      rescue ArgumentError
        nil
      end

      def public_url(cnpj, year, sequence)
        return nil unless cnpj && year && sequence

        format(PUBLIC_URL, cnpj: cnpj, year: year, sequence: sequence)
      end
  end
end
