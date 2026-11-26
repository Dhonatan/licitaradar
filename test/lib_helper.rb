# Helper for the framework-independent tests in test/lib.
# These run with plain Ruby (`bin/test-lib`) and also as part of `bin/rails test`.
require "minitest/autorun"
require "date"
require "json"

PNCP_LIB = File.expand_path("../lib/pncp", __dir__)
%w[ error http_error invalid_record page modalities pii_scrubber values net_http_transport http_client tender_normalizer client ].each do |file|
  require File.join(PNCP_LIB, file)
end

module PncpTestSupport
  FIXTURES = File.expand_path("fixtures/files/pncp", __dir__)

  def pncp_fixture(name)
    File.read(File.join(FIXTURES, name), encoding: "UTF-8")
  end

  def pncp_record(name = "proposta_page_1.json", index: 0)
    JSON.parse(pncp_fixture(name)).fetch("data").fetch(index)
  end

  # In-memory transport: returns queued responses in order and records requests.
  class FakeTransport
    Response = Struct.new(:status, :body)

    attr_reader :requests

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def get(uri, headers = {})
      @requests << { uri: uri, headers: headers }
      response = @responses.shift || raise("FakeTransport: no response queued for #{uri}")
      raise response if response.is_a?(Exception)

      Response.new(*response)
    end

    def queries
      @requests.map { |request| URI.decode_www_form(request[:uri].query.to_s).to_h }
    end
  end
end
