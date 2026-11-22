# Operational alerts for whoever runs the instance. Recipients come from ADMIN_EMAIL
# (one address or a comma-separated list); nothing is sent when it is not set.
class AdminMailer < ApplicationMailer
  def self.recipients
    ENV.fetch("ADMIN_EMAIL", "").split(",").map(&:strip).compact_blank
  end

  # runs: the SyncRuns that failed on the last automatic attempt.
  def sync_failed(runs)
    @runs = runs
    @status_url = status_url

    mail to: self.class.recipients,
         subject: "[LicitaRadar] Falha na sincronização com o PNCP (#{runs.size} #{runs.one? ? "modalidade" : "modalidades"})"
  end
end
