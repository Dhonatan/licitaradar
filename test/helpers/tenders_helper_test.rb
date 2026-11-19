require "test_helper"

class TendersHelperTest < ActionView::TestCase
  setup do
    # Thursday, 10:00 in Brasília.
    @now = Time.zone.local(2026, 11, 19, 10, 0)
  end

  test "brl formats Brazilian reais" do
    assert_equal "R$ 1.234,50", brl(1234.5)
    assert_equal "R$ 1.500.000,00", brl(BigDecimal("1500000"))
    assert_equal "R$ 0,99", brl(0.99)
  end

  test "tender_value shows a confidential label for zero or missing estimates" do
    assert_equal "R$ 10.000,00", tender_value(Tender.new(estimated_value: 10_000))
    assert_match "Valor sigiloso", tender_value(Tender.new(estimated_value: 0))
    assert_match "Valor sigiloso", tender_value(Tender.new(estimated_value: nil))
  end

  test "dates are formatted the Brazilian way" do
    assert_equal "19/11/2026 às 10:00", date_time_br(@now)
    assert_equal "19/11/2026", date_br(@now)
    assert_nil date_time_br(nil)
  end

  test "deadline_text counts calendar days" do
    assert_equal "encerra hoje às 18:00", deadline_text(@now.change(hour: 18), now: @now)
    assert_equal "encerra amanhã", deadline_text(@now + 1.day - 9.hours, now: @now)
    assert_equal "encerra em 3 dias", deadline_text(@now + 3.days, now: @now)
    assert_equal "encerrado", deadline_text(@now - 1.minute, now: @now)
    assert_equal "prazo não informado", deadline_text(nil, now: @now)
  end

  test "deadline_level grades urgency" do
    assert_equal "urgent", deadline_level(@now + 2.hours, now: @now)
    assert_equal "urgent", deadline_level(@now + 1.day, now: @now)
    assert_equal "soon", deadline_level(@now + 7.days, now: @now)
    assert_equal "ok", deadline_level(@now + 8.days, now: @now)
    assert_equal "closed", deadline_level(@now - 1.second, now: @now)
    assert_equal "unknown", deadline_level(nil, now: @now)
  end

  test "deadline_badge renders the text with an urgency class and the full date" do
    render inline: "<%= deadline_badge(close_at, now: now) %>", locals: { close_at: @now + 3.days, now: @now }

    assert_select "span.badge.badge--soon[title=?]", "22/11/2026 às 10:00", text: "encerra em 3 dias"
  end

  test "time_left gives a precise countdown" do
    assert_equal "3 dias e 4 horas", time_left(@now + 3.days + 4.hours + 5.minutes, now: @now)
    assert_equal "1 dia", time_left(@now + 1.day + 10.minutes, now: @now)
    assert_equal "5 horas e 12 minutos", time_left(@now + 5.hours + 12.minutes, now: @now)
    assert_equal "1 hora", time_left(@now + 1.hour, now: @now)
    assert_equal "1 minuto", time_left(@now + 20.seconds, now: @now)
    assert_nil time_left(@now - 1.minute, now: @now)
    assert_nil time_left(nil, now: @now)
  end

  test "tender_location and tender_modality" do
    assert_equal "Recife/PE", tender_location(Tender.new(city: "Recife", state: "PE"))
    assert_equal "PE", tender_location(Tender.new(state: "PE"))
    assert_nil tender_location(Tender.new)
    assert_equal "Pregão - Eletrônico", tender_modality(Tender.new(modality_id: 6))
    assert_equal "Pregão Eletrônico SRP", tender_modality(Tender.new(modality_id: 6, modality_name: "Pregão Eletrônico SRP"))
    assert_nil tender_modality(Tender.new)
  end

  test "external_url only allows http and https" do
    assert_equal "https://example.gov.br/edital/1", external_url(" https://example.gov.br/edital/1 ")
    assert_equal "http://example.gov.br", external_url("http://example.gov.br")
    assert_nil external_url("javascript:alert(1)")
    assert_nil external_url("ftp://example.gov.br")
    assert_nil external_url("not a url")
    assert_nil external_url(nil)
  end
end
