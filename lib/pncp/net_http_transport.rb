require "net/http"
require "uri"

module Pncp
  # Minimal HTTP transport built on Net::HTTP (respects HTTPS_PROXY / HTTP_PROXY).
  # Anything that responds to #get(uri, headers) and returns an object with
  # #status and #body can replace it — tests use an in-memory fake.
  class NetHttpTransport
    Response = Struct.new(:status, :body)

    def initialize(open_timeout: 10, read_timeout: 60)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def get(uri, headers = {})
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      response = http.request(Net::HTTP::Get.new(uri, headers))
      Response.new(response.code.to_i, response.body)
    end
  end
end
