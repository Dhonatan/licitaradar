require "bigdecimal"
require "time"

module Pncp
  # Parsing of the loosely typed values the PNCP sends: blank strings for nil, numbers
  # as strings or floats, and Brasília local times without an offset. Shared by the
  # normalizers (included as private helpers) and usable as Pncp::Values.time(...).
  module Values
    BRASILIA_OFFSET = "-03:00".freeze

    module_function

    # Stripped text, or nil when blank.
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

    # true/false, also from "true"/"false" strings; nil when missing or unknown.
    def boolean(value)
      case value
      when true, false then value
      when String then { "true" => true, "false" => false }[value.strip.downcase]
      end
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
  end
end
