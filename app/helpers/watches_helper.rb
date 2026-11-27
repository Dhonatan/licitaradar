module WatchesHelper
  PROPOSALS_STATUSES = {
    "open" => [ "aberta", "ok" ],
    "closing_today" => [ "encerra hoje", "urgent" ],
    "closed" => [ "encerrada", "closed" ],
    "unknown" => [ "prazo não informado", "unknown" ]
  }.freeze

  # "aberta", "encerra hoje" or "encerrada" (see Tender#proposals_status).
  def proposals_status_badge(tender, now: Time.current)
    label, level = PROPOSALS_STATUSES.fetch(tender.proposals_status(now: now))
    tag.span(label, class: [ "badge", "badge--#{level}" ])
  end
end
