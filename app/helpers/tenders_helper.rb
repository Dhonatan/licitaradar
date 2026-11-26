module TendersHelper
  SPHERES = { "F" => "Federal", "E" => "Estadual", "M" => "Municipal", "D" => "Distrital" }.freeze
  POWERS = { "E" => "Executivo", "L" => "Legislativo", "J" => "Judiciário" }.freeze

  # 1234.5 => "R$ 1.234,50"
  def brl(amount)
    number_to_currency(amount, unit: "R$", separator: ",", delimiter: ".", format: "%u %n", precision: 2)
  end

  # PNCP publishes 0 (or nothing) when the estimate is confidential ("orçamento sigiloso").
  def tender_value(tender)
    if tender.confidential_value?
      tag.span("Valor sigiloso", class: "muted", title: "O órgão não divulgou o valor estimado (orçamento sigiloso).")
    else
      brl(tender.estimated_value)
    end
  end

  # Item values keep up to 4 decimal places (unit prices like R$ 0,0125).
  def item_value(amount)
    if amount.nil?
      tag.span("sigiloso", class: "muted", title: "O órgão não divulgou o valor estimado deste item (orçamento sigiloso).")
    else
      return brl(amount) if amount.round(2) == amount

      number_to_currency(amount, unit: "R$", separator: ",", delimiter: ".", format: "%u %n", precision: 4, strip_insignificant_zeros: true)
    end
  end

  def item_quantity(quantity)
    number_with_precision(quantity, precision: 4, strip_insignificant_zeros: true, separator: ",", delimiter: ".")
  end

  def date_time_br(time)
    time&.strftime("%d/%m/%Y às %H:%M")
  end

  def date_br(time)
    time&.strftime("%d/%m/%Y")
  end

  # Short, calendar-based deadline text: "encerra hoje às 14:00", "encerra amanhã",
  # "encerra em 3 dias", "encerrado".
  def deadline_text(close_at, now: Time.current)
    return "prazo não informado" if close_at.nil?
    return "encerrado" if close_at <= now

    case days = days_until(close_at, now)
    when 0 then "encerra hoje às #{close_at.strftime("%H:%M")}"
    when 1 then "encerra amanhã"
    else "encerra em #{days} dias"
    end
  end

  # "closed", "urgent" (today/tomorrow), "soon" (within a week), "ok" or "unknown".
  def deadline_level(close_at, now: Time.current)
    return "unknown" if close_at.nil?
    return "closed" if close_at <= now

    days = days_until(close_at, now)
    return "urgent" if days <= 1

    days <= 7 ? "soon" : "ok"
  end

  def deadline_badge(close_at, now: Time.current)
    tag.span(deadline_text(close_at, now: now), class: [ "badge", "badge--#{deadline_level(close_at, now: now)}" ], title: date_time_br(close_at))
  end

  # Precise countdown for the detail page: "3 dias e 4 horas", "5 horas e 12 minutos".
  def time_left(close_at, now: Time.current)
    return if close_at.nil? || close_at <= now

    days, seconds = (close_at - now).to_i.divmod(1.day.to_i)
    hours, seconds = seconds.divmod(1.hour.to_i)
    minutes = seconds / 1.minute.to_i

    countdown_parts(days, hours, minutes).join(" e ")
  end

  def tender_location(tender)
    [ tender.city, tender.state ].compact_blank.join("/").presence
  end

  def tender_modality(tender)
    tender.modality_name.presence || (Pncp::Modalities.name_for(tender.modality_id) if tender.modality_id)
  end

  # "Municipal · Executivo"
  def agency_scope(tender)
    [ SPHERES[tender.agency_sphere], POWERS[tender.agency_power] ].compact.join(" · ").presence
  end

  # "00000000000191" => "00.000.000/0001-91"
  def format_cnpj(cnpj)
    digits = cnpj.to_s.gsub(/\D/, "")
    return cnpj.presence if digits.length != 14

    "#{digits[0, 2]}.#{digits[2, 3]}.#{digits[5, 3]}/#{digits[8, 4]}-#{digits[12, 2]}"
  end

  # Only http(s) URLs are rendered as links (the origin URL comes from third-party systems).
  def external_url(url)
    uri = URI.parse(url.to_s.strip)
    uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  private
    def countdown_parts(days, hours, minutes)
      if days.positive?
        [ pluralize(days, "dia", plural: "dias"), (pluralize(hours, "hora", plural: "horas") if hours.positive?) ].compact
      elsif hours.positive?
        [ pluralize(hours, "hora", plural: "horas"), (pluralize(minutes, "minuto", plural: "minutos") if minutes.positive?) ].compact
      else
        [ pluralize([ minutes, 1 ].max, "minuto", plural: "minutos") ]
      end
    end

    def days_until(close_at, now)
      (close_at.in_time_zone.to_date - now.in_time_zone.to_date).to_i
    end
end
