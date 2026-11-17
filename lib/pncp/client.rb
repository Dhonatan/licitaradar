require "date"
require "json"
require "openssl"
require "socket"
require "timeout"
require "uri"

module Pncp
  # Client for the public PNCP query API (https://pncp.gov.br/api/consulta).
  #
  # The API needs no authentication, but it is slow, occasionally returns 5xx and
  # answers 204 (no body) when a query has no results. This client hides those
  # details: it retries transient failures with exponential backoff, treats 204
  # as an empty page and walks through every page for you.
  #
  # Note: the API silently ignores keyword filters, so LicitaRadar fetches by
  # modality/date window and does the text search in its own database.
  #
  #   client = Pncp::Client.new
  #   client.each_open_tender(modality_id: 6, until_date: Date.today + 60) do |record|
  #     Pncp::TenderNormalizer.call(record)
  #   end
  class Client
    BASE_URL = "https://pncp.gov.br/api/consulta".freeze
    DEFAULT_PAGE_SIZE = 50
    MAX_PAGE_SIZE = 500
    USER_AGENT = "LicitaRadar/0.1 (+https://github.com/Dhonatan/licitaradar)".freeze

    NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError ].freeze

    def initialize(base_url: ENV.fetch("PNCP_BASE_URL", BASE_URL), transport: NetHttpTransport.new,
                   max_retries: 3, backoff: 2.0, sleeper: ->(seconds) { sleep(seconds) }, user_agent: USER_AGENT)
      @base_url = base_url.to_s.chomp("/")
      @transport = transport
      @max_retries = max_retries
      @backoff = backoff
      @sleeper = sleeper
      @user_agent = user_agent
    end

    # Tenders whose proposal period is still open (GET /v1/contratacoes/proposta).
    # `until_date` is the last proposal deadline to include.
    def open_tenders(modality_id:, until_date:, page: 1, page_size: DEFAULT_PAGE_SIZE, state: nil)
      fetch_page "/v1/contratacoes/proposta", page, {
        dataFinal: format_date(until_date),
        codigoModalidadeContratacao: modality_id,
        uf: state,
        pagina: page,
        tamanhoPagina: clamp_page_size(page_size)
      }
    end

    # Tenders published in a date window (GET /v1/contratacoes/publicacao).
    def published_tenders(modality_id:, from:, to:, page: 1, page_size: DEFAULT_PAGE_SIZE, state: nil)
      fetch_page "/v1/contratacoes/publicacao", page, {
        dataInicial: format_date(from),
        dataFinal: format_date(to),
        codigoModalidadeContratacao: modality_id,
        uf: state,
        pagina: page,
        tamanhoPagina: clamp_page_size(page_size)
      }
    end

    # Yields every raw record across all pages of #open_tenders.
    def each_open_tender(max_pages: nil, **params, &block)
      return enum_for(:each_open_tender, max_pages: max_pages, **params) unless block

      each_page(max_pages: max_pages) { |number| open_tenders(page: number, **params) }
        .each { |page| page.records.each(&block) }
    end

    # Yields every raw record across all pages of #published_tenders.
    def each_published_tender(max_pages: nil, **params, &block)
      return enum_for(:each_published_tender, max_pages: max_pages, **params) unless block

      each_page(max_pages: max_pages) { |number| published_tenders(page: number, **params) }
        .each { |page| page.records.each(&block) }
    end

    # Lazily walks pages, stopping at the last page, an empty page or max_pages.
    def each_page(max_pages: nil, &fetch)
      Enumerator.new do |pages|
        number = 1
        loop do
          page = fetch.call(number)
          pages << page
          break if page.last? || page.empty? || (max_pages && number >= max_pages)

          number += 1
        end
      end
    end

    private
      def fetch_page(path, number, params)
        uri = build_uri(path, params)
        response = with_retries { request(uri) }
        # Net::HTTP hands back a binary (ASCII-8BIT) body; the API always speaks UTF-8.
        body = response.body.to_s.dup.force_encoding(Encoding::UTF_8)
        return Page.empty(number) if response.status == 204 || body.strip.empty?

        Page.from_payload(JSON.parse(body), number: number)
      rescue JSON::ParserError => error
        raise Error, "Invalid JSON from PNCP (#{uri}): #{error.message}"
      end

      def request(uri)
        response = @transport.get(uri, "Accept" => "application/json", "User-Agent" => @user_agent)
        raise HttpError.new(response.status, response.body) unless (200..299).cover?(response.status)

        response
      end

      def with_retries
        attempts = 0
        begin
          attempts += 1
          yield
        rescue HttpError => error
          raise if !error.retryable? || attempts > @max_retries

          pause(attempts)
          retry
        rescue *NETWORK_ERRORS => error
          raise Error, "Network error talking to PNCP: #{error.class}: #{error.message}" if attempts > @max_retries

          pause(attempts)
          retry
        end
      end

      def pause(attempt)
        @sleeper.call(@backoff * (2**(attempt - 1)))
      end

      def build_uri(path, params)
        URI("#{@base_url}#{path}").tap do |uri|
          uri.query = URI.encode_www_form(params.compact)
        end
      end

      def format_date(value)
        value.respond_to?(:strftime) ? value.strftime("%Y%m%d") : value.to_s.delete("-")
      end

      def clamp_page_size(size)
        size.to_i.clamp(1, MAX_PAGE_SIZE)
      end
  end
end
