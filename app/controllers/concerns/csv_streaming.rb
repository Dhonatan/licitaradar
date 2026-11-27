# Streams an Enumerable of CSV chunks (Tenders::CsvExport) as a download: the rows are
# generated while the response is sent, so a 5,000-row export never sits in memory.
module CsvStreaming
  extend ActiveSupport::Concern

  private
    def stream_csv(chunks, filename:)
      headers["Content-Type"] = "text/csv; charset=utf-8"
      headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename)
      headers["Cache-Control"] = "no-store"
      # Proxies (nginx) must not buffer the stream; with Last-Modified set, Rack::ETag does
      # not read the whole body to compute an ETag.
      headers["X-Accel-Buffering"] = "no"
      headers["Last-Modified"] = Time.current.httpdate
      headers.delete("Content-Length")

      self.response_body = chunks
    end
end
