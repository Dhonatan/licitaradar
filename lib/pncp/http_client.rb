require "json"
require "openssl"
require "socket"
require "timeout"
require "uri"

module Pncp
  # What every PNCP client shares: GET + JSON over a swappable transport, retries with
  # exponential backoff for rate limiting (429), server errors (5xx) and network
  # failures, and "204 No Content" read as "no results".
  #
  # Subclasses (Client, IntegrationClient) only build paths and parameters.
  class HttpClient
    USER_AGENT = "LicitaRadar/0.1 (+https://github.com/Dhonatan/licitaradar)".freeze

    NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError ].freeze

    attr_reader :base_url

    def initialize(base_url:, transport: NetHttpTransport.new, max_retries: 3, backoff: 2.0,
                   sleeper: ->(seconds) { sleep(seconds) }, user_agent: USER_AGENT)
      @base_url = base_url.to_s.chomp("/")
      @transport = transport
      @max_retries = max_retries
      @backoff = backoff
      @sleeper = sleeper
      @user_agent = user_agent
    end

    private
      # The parsed JSON body, or nil when the API answers 204 or an empty body.
      def get_json(path, params = {})
        uri = build_uri(path, params)
        response = with_retries { request(uri) }
        # Net::HTTP hands back a binary (ASCII-8BIT) body; the API always speaks UTF-8.
        body = response.body.to_s.dup.force_encoding(Encoding::UTF_8)
        return nil if response.status == 204 || body.strip.empty?

        JSON.parse(body)
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
          query = params.compact
          uri.query = URI.encode_www_form(query) unless query.empty?
        end
      end
  end
end
