module Pncp
  # Client for the public GET endpoints of the PNCP integration API
  # (https://pncp.gov.br/api/pncp, "Manual de Integração do PNCP", sections 11.8 and 11.13),
  # which give the details of one tender ("contratação"): its documents and its items.
  # They need no authentication. Retries and 204 handling come from HttpClient.
  #
  #   client = Pncp::IntegrationClient.new
  #   client.documents(cnpj: "00000000000191", year: 2026, sequence: 12)  # => [ { "titulo" => ... } ]
  #   client.all_items(cnpj: "00000000000191", year: 2026, sequence: 12)  # => [ { "numeroItem" => 1, ... } ]
  class IntegrationClient < HttpClient
    BASE_URL = "https://pncp.gov.br/api/pncp".freeze
    ITEMS_PAGE_SIZE = 50
    # 40 pages of 50: tenders with more than 2,000 items are cut there.
    MAX_ITEM_PAGES = 40

    # Same options as HttpClient (transport, max_retries, backoff, sleeper, user_agent).
    def initialize(base_url: ENV.fetch("PNCP_INTEGRATION_BASE_URL", BASE_URL), **options)
      super(base_url: base_url, **options)
    end

    # Every document of a tender (GET /v1/orgaos/{cnpj}/compras/{ano}/{sequencial}/arquivos,
    # not paginated). Raw records; see DocumentNormalizer.
    def documents(cnpj:, year:, sequence:)
      records(get_json("#{purchase_path(cnpj, year, sequence)}/arquivos"), "documentos")
    end

    # One page of items (GET .../itens?pagina=&tamanhoPagina=). Raw records; see ItemNormalizer.
    def items(cnpj:, year:, sequence:, page: 1, page_size: ITEMS_PAGE_SIZE)
      path = "#{purchase_path(cnpj, year, sequence)}/itens"
      records(get_json(path, pagina: page, tamanhoPagina: page_size), "itens")
    end

    # Every item of a tender. The endpoint returns a plain list without totals, so pages
    # are read until one comes back short (or repeats items already seen, in case the
    # API ignores the paging parameters), up to max_pages.
    def all_items(cnpj:, year:, sequence:, page_size: ITEMS_PAGE_SIZE, max_pages: MAX_ITEM_PAGES)
      by_number = {}
      (1..max_pages).each do |page|
        batch = items(cnpj: cnpj, year: year, sequence: sequence, page: page, page_size: page_size)
        fresh = batch.reject { |record| by_number.key?(record["numeroItem"]) }
        fresh.each { |record| by_number[record["numeroItem"]] = record }
        break if batch.size < page_size || fresh.empty?
      end
      by_number.values
    end

    # Base URL of a tender in this API (documents are downloaded below it).
    def purchase_url(cnpj:, year:, sequence:)
      "#{base_url}#{purchase_path(cnpj, year, sequence)}"
    end

    private
      def purchase_path(cnpj, year, sequence)
        cnpj = cnpj.to_s.delete("^0-9")
        year = Values.integer(year)
        sequence = Values.integer(sequence)
        unless cnpj.length == 14 && year&.positive? && sequence&.positive?
          raise ArgumentError, "a tender needs the agency CNPJ (14 digits), year and sequence"
        end

        "/v1/orgaos/#{cnpj}/compras/#{year}/#{sequence}"
      end

      # The manual lists the fields under "documentos"/"itens"; the API answers with a plain
      # JSON array. Both shapes are accepted.
      def records(payload, key)
        list = payload.is_a?(Hash) ? (payload[key] || payload["data"]) : payload
        Array(list).grep(Hash)
      end
  end
end
