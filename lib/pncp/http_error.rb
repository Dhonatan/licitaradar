module Pncp
  # Raised when the PNCP API answers with a non-2xx status.
  class HttpError < Error
    attr_reader :status, :body

    def initialize(status, body = nil)
      @status = status.to_i
      @body = body
      super("PNCP answered HTTP #{@status}")
    end

    # Rate limiting and server-side failures are worth retrying; client errors are not.
    def retryable?
      status == 429 || status >= 500
    end
  end
end
