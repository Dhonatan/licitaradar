# Refreshes the tenders still open for proposals (see Tenders::Sync).
# Scheduled every few hours; can also be run by hand with `bin/rails pncp:sync`.
class SyncOpenTendersJob < ApplicationJob
  queue_as :default

  # modality_ids: optional list of PNCP modality ids (defaults to the competitive ones).
  def perform(modality_ids = nil)
    options = modality_ids.present? ? { modality_ids: modality_ids } : {}
    Tenders::Sync.call(**options)
  end
end
