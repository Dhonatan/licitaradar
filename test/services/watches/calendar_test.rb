require "test_helper"

module Watches
  class CalendarTest < ActiveSupport::TestCase
    # URL helpers for the feed, like the controller provides.
    class Urls
      include Rails.application.routes.url_helpers

      def default_url_options
        { host: "licitaradar.example.com", protocol: "https" }
      end
    end

    setup do
      @now = Time.zone.parse("2026-11-27 10:00")
      @user = create_user
    end

    def calendar
      Calendar.new(@user, urls: Urls.new, now: @now)
    end

    def unfold(ics)
      ics.gsub("\r\n ", "")
    end

    def events(ics)
      unfold(ics).scan(/BEGIN:VEVENT\r\n(.*?)END:VEVENT/m).map { |(body)| body.split("\r\n").to_h { |line| line.split(":", 2) } }
    end

    test "a calendar with one event per watched deadline" do
      tender = create_open_tender(object_description: "Serviço de buffet para formatura", agency_name: "Prefeitura de Exemplópolis",
                                  city: "Exemplópolis", state: "PE", proposals_close_at: Time.zone.parse("2026-12-02 14:00"))
      Watch.watch!(@user, tender)

      ics = calendar.to_ics

      assert ics.start_with?("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:")
      assert ics.end_with?("END:VCALENDAR\r\n")
      assert_includes ics, "METHOD:PUBLISH\r\n"
      assert_no_match(/(?<!\r)\n/, ics, "every line must end with CRLF")

      event = events(ics).sole
      assert_equal "licitaradar-user-#{@user.id}-tender-#{tender.id}", event["UID"]
      assert_equal "20261202T163000Z", event["DTSTART"]
      assert_equal "20261202T170000Z", event["DTEND"]
      assert_equal "20261127T130000Z", event["DTSTAMP"]
      assert_equal "Prazo: Serviço de buffet para formatura", event["SUMMARY"]
      assert_equal "https://licitaradar.example.com/tenders/#{tender.id}", event["URL"]
      assert_includes event["DESCRIPTION"], "Fim do prazo de propostas: 02/12/2026 às 14:00 (horário de Brasília)\\n"
      assert_includes event["DESCRIPTION"], "Órgão: Prefeitura de Exemplópolis"
      assert_includes event["DESCRIPTION"], "Local: Exemplópolis/PE"
    end

    test "lists upcoming and recent deadlines only, in order" do
      later = Watch.watch!(@user, create_open_tender(proposals_close_at: @now + 10.days)).tender
      sooner = Watch.watch!(@user, create_open_tender(proposals_close_at: @now + 1.day)).tender
      recent = Watch.watch!(@user, create_open_tender(proposals_close_at: @now - 29.days)).tender
      Watch.watch!(@user, create_open_tender(proposals_close_at: @now - 31.days))
      Watch.watch!(@user, create_open_tender(proposals_close_at: nil))
      Watch.watch!(create_user, create_open_tender(proposals_close_at: @now + 2.days))

      uids = events(calendar.to_ics).map { |event| event["UID"] }

      assert_equal [ recent, sooner, later ].map { |tender| "licitaradar-user-#{@user.id}-tender-#{tender.id}" }, uids
    end

    test "an empty calendar is still valid" do
      ics = calendar.to_ics

      assert_includes ics, "BEGIN:VCALENDAR\r\n"
      assert_includes ics, "END:VCALENDAR\r\n"
      assert_not_includes ics, "BEGIN:VEVENT"
    end

    test "text values are escaped" do
      Watch.watch!(@user, create_open_tender(object_description: "Obras; reforma, pintura \\ limpeza\nfase 2"))

      summary = events(calendar.to_ics).sole["SUMMARY"]

      assert_equal "Prazo: Obras\\; reforma\\, pintura \\\\ limpeza fase 2", summary
    end

    test "long lines are folded at 75 octets without splitting characters" do
      Watch.watch!(@user, create_open_tender(object_description: "Aquisição de материалов e serviços de manutenção " * 6))

      ics = calendar.to_ics

      ics.split("\r\n").each do |line|
        assert_operator line.bytesize, :<=, 75, line
        assert line.valid_encoding?
      end
      assert ics.split("\r\n").any? { |line| line.start_with?(" ") }
      assert_includes unfold(ics), "SUMMARY:Prazo: Aquisição de материалов e serviços"
    end

    test "private notes never appear in the feed" do
      watch = Watch.watch!(@user, create_open_tender)
      watch.update!(note: "Margem mínima de 12%")

      assert_not_includes unfold(calendar.to_ics), "Margem mínima"
    end
  end
end
