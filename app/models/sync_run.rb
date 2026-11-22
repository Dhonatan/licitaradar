# Audit log of one PNCP sync pass for one modality (see Tenders::Sync).
class SyncRun < ApplicationRecord
  # A run still "running" after this long was interrupted (deploy, crash, OOM kill).
  ABANDONED_AFTER = 3.hours

  enum :status, { running: "running", succeeded: "succeeded", failed: "failed" }, validate: true

  validates :modality_id, :started_at, presence: true
  validates :pages, :fetched_count, :upserted_count, :skipped_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :attempt, numericality: { only_integer: true, greater_than: 0 }

  scope :recent, -> { order(started_at: :desc) }

  def self.last_succeeded_at
    succeeded.maximum(:finished_at)
  end

  # Marks runs left "running" by a process that died as failed, so they don't look busy
  # forever on the status page. Returns how many were closed.
  def self.fail_abandoned!(now: Time.current)
    running.where(started_at: ...(now - ABANDONED_AFTER))
      .update_all(status: "failed", finished_at: now, error_message: "Interrompida: o processo terminou antes do fim da sincronização.", updated_at: now)
  end

  # The most recent run of each modality, keyed by modality id.
  def self.latest_by_modality
    where(id: select("DISTINCT ON (modality_id) id").order(:modality_id, started_at: :desc, id: :desc))
      .index_by(&:modality_id)
  end

  # Failed runs of a modality since its last successful one.
  def self.failures_in_a_row(modality_id)
    last_success = succeeded.where(modality_id: modality_id).maximum(:started_at)
    runs = failed.where(modality_id: modality_id)
    runs = runs.where(started_at: last_success..) if last_success
    runs.count
  end

  def modality_name
    Pncp::Modalities.name_for(modality_id)
  end

  def duration
    finished_at - started_at if finished_at
  end
end
