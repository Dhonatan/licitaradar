module Pncp
  # One page of results from a paginated PNCP endpoint.
  Page = Struct.new(:records, :number, :total_pages, :total_records, :remaining_pages, keyword_init: true) do
    def self.empty(number = 1)
      new(records: [], number: number, total_pages: 0, total_records: 0, remaining_pages: 0)
    end

    def self.from_payload(payload, number:)
      new(
        records: Array(payload["data"]),
        number: (payload["numeroPagina"] || number).to_i,
        total_pages: payload["totalPaginas"].to_i,
        total_records: payload["totalRegistros"].to_i,
        remaining_pages: payload["paginasRestantes"].to_i
      )
    end

    def last?
      remaining_pages.to_i <= 0
    end

    def empty?
      records.empty?
    end
  end
end
