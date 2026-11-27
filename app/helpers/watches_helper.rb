module WatchesHelper
  PROPOSALS_STATUSES = {
    "open" => [ "aberta", "ok" ],
    "closing_today" => [ "encerra hoje", "urgent" ],
    "closed" => [ "encerrada", "closed" ],
    "unknown" => [ "prazo não informado", "unknown" ]
  }.freeze

  # Options of the deadline reminder setting (User::DEADLINE_REMINDER_OPTIONS).
  def deadline_reminder_options
    User::DEADLINE_REMINDER_OPTIONS.map do |days|
      label = { 0 => "Não enviar lembretes", 1 => "1 dia antes do prazo" }.fetch(days) { "#{days} dias antes do prazo" }
      [ label, days ]
    end
  end

  # "aberta", "encerra hoje" or "encerrada" (see Tender#proposals_status).
  def proposals_status_badge(tender, now: Time.current)
    label, level = PROPOSALS_STATUSES.fetch(tender.proposals_status(now: now))
    tag.span(label, class: [ "badge", "badge--#{level}" ])
  end
end
