module Watches
  # iCalendar (RFC 5545) feed with the proposals deadlines of a user's watched tenders, for
  # calendar apps to subscribe to (CalendarFeedsController). One event per tender, the
  # EVENT_LENGTH before the deadline, for deadlines from PAST_DAYS ago on. Private notes
  # are never included: the feed URL ends up in third-party calendar services.
  #
  #   Watches::Calendar.new(user, urls: controller).to_ics  # => "BEGIN:VCALENDAR\r\n..."
  class Calendar
    PAST_DAYS = 30
    EVENT_LENGTH = 30.minutes
    PRODID = "-//LicitaRadar//Prazos de licitações//PT-BR".freeze
    # Lines longer than this many octets are folded (RFC 5545, 3.1).
    LINE_LIMIT = 75

    attr_reader :user, :urls, :now

    # urls: anything with the app's URL helpers (the controller).
    def initialize(user, urls:, now: Time.current)
      @user = user
      @urls = urls
      @now = now
    end

    def watches
      user.watches.joins(:tender)
        .where(tenders: { proposals_close_at: (now - PAST_DAYS.days).. })
        .preload(:tender).order("tenders.proposals_close_at ASC, watches.id ASC")
    end

    def to_ics
      lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:#{PRODID}",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-CALNAME:#{text("LicitaRadar – prazos de propostas")}",
        "X-WR-TIMEZONE:America/Sao_Paulo",
        "REFRESH-INTERVAL;VALUE=DURATION:PT6H",
        "X-PUBLISHED-TTL:PT6H"
      ]
      watches.each { |watch| lines.concat(event(watch.tender)) }
      lines << "END:VCALENDAR"

      lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
    end

    private
      def event(tender)
        close_at = tender.proposals_close_at

        [
          "BEGIN:VEVENT",
          "UID:licitaradar-user-#{user.id}-tender-#{tender.id}",
          "DTSTAMP:#{utc(now)}",
          "LAST-MODIFIED:#{utc(tender.updated_at)}",
          "DTSTART:#{utc(close_at - EVENT_LENGTH)}",
          "DTEND:#{utc(close_at)}",
          "SUMMARY:#{text("Prazo: #{(tender.object_description.presence || "Licitação").squish.truncate(120)}")}",
          "DESCRIPTION:#{text(description(tender))}",
          "URL:#{urls.tender_url(tender)}",
          "TRANSP:TRANSPARENT",
          "END:VEVENT"
        ]
      end

      def description(tender)
        [
          "Fim do prazo de propostas: #{tender.proposals_close_at.strftime("%d/%m/%Y às %H:%M")} (horário de Brasília)",
          tender.object_description.to_s.squish.truncate(500).presence,
          ("Órgão: #{tender.agency_name}" if tender.agency_name.present?),
          ("Local: #{[ tender.city, tender.state ].compact_blank.join("/")}" if tender.city.present? || tender.state.present?),
          ("Modalidade: #{tender.modality_name}" if tender.modality_name.present?),
          "Nº de controle PNCP: #{tender.pncp_control_number}",
          urls.tender_url(tender)
        ].compact.join("\n")
      end

      def utc(time)
        time.utc.strftime("%Y%m%dT%H%M%SZ")
      end

      # TEXT values escape backslashes, semicolons, commas and line breaks (RFC 5545, 3.3.11).
      def text(value)
        value.to_s.gsub("\\") { "\\\\" }.gsub(/\r\n|\r|\n/) { "\\n" }.gsub(/([;,])/) { "\\#{$1}" }
      end

      # Splits lines longer than LINE_LIMIT octets, never inside a UTF-8 character;
      # continuation lines start with a space.
      def fold(line)
        return line if line.bytesize <= LINE_LIMIT

        parts = [ +"" ]
        line.each_char do |char|
          limit = parts.one? ? LINE_LIMIT : LINE_LIMIT - 1
          parts << +"" if parts.last.bytesize + char.bytesize > limit
          parts.last << char
        end
        parts.join("\r\n ")
      end
  end
end
