module Pncp
  # Turns one document record of a tender (IntegrationClient#documents) into the
  # attributes of a `tender_documents` row.
  #
  #   Pncp::DocumentNormalizer.call(record, purchase_url: client.purchase_url(...))
  #   # => { sequence: 1, title: "Edital", type_id: 2, type_name: "Edital", url: "https://...", ... }
  #
  # `purchase_url` is used to build the download link when the record has none.
  class DocumentNormalizer
    include Values

    def self.call(record, purchase_url: nil)
      new(record, purchase_url: purchase_url).call
    end

    def initialize(record, purchase_url: nil)
      @record = record || {}
      @purchase_url = purchase_url
    end

    def call
      sequence = integer(@record["sequencialDocumento"])
      raise InvalidRecord, "document without sequencialDocumento" unless sequence

      type_name = string(@record["tipoDocumentoNome"]) || string(@record["tipoDocumentoDescricao"])
      {
        sequence: sequence,
        title: PiiScrubber.call(string(@record["titulo"])) || type_name || "Documento #{sequence}",
        type_id: integer(@record["tipoDocumentoId"]),
        type_name: type_name,
        url: string(@record["url"]) || string(@record["uri"]) || download_url(sequence),
        published_at: time(@record["dataPublicacaoPncp"]),
        active: boolean(@record["statusAtivo"]) != false
      }
    end

    private
      def download_url(sequence)
        "#{@purchase_url}/arquivos/#{sequence}" if @purchase_url
      end
  end
end
