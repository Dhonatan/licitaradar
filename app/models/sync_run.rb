# Audit log of one PNCP sync pass for one modality (see Tenders::Sync).
class SyncRun < ApplicationRecord
  enum :status, { running: "running", succeeded: "succeeded", failed: "failed" }, validate: true

  validates :modality_id, :started_at, presence: true
  validates :pages, :fetched_count, :upserted_count, :skipped_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(started_at: :desc) }

  def self.last_succeeded_at
    succeeded.maximum(:finished_at)
  end

  def modality_name
    Pncp::Modalities.name_for(modality_id)
  end

  def duration
    finished_at - started_at if finished_at
  end
end
