# What the admin status page (/status) shows: the sync health of each PNCP modality, a few
# counts and the background job queue.
#
#   status = SystemStatus.new
#   status.healthy?    # every competitive modality synced successfully in the last 12 hours
#   status.modalities  # => [ SystemStatus::Modality, ... ]
class SystemStatus
  # The sync runs every 6 hours; one missed run is tolerated.
  STALE_AFTER = 12.hours

  Modality = Data.define(:modality_id, :name, :latest_run, :last_succeeded_at, :failures_in_a_row) do
    def healthy?(now = Time.current)
      last_succeeded_at.present? && last_succeeded_at > now - STALE_AFTER && !latest_run&.failed?
    end
  end

  attr_reader :checked_at

  def initialize(now: Time.current)
    @checked_at = now
  end

  # Competitive modalities first, then any other modality that has sync runs.
  def modalities
    @modalities ||= begin
      latest = SyncRun.latest_by_modality
      last_succeeded = SyncRun.succeeded.group(:modality_id).maximum(:finished_at)

      (Pncp::Modalities::COMPETITIVE + latest.keys.sort).uniq.map do |id|
        Modality.new(modality_id: id, name: Pncp::Modalities.name_for(id), latest_run: latest[id],
                     last_succeeded_at: last_succeeded[id], failures_in_a_row: SyncRun.failures_in_a_row(id))
      end
    end
  end

  def healthy?
    modalities.all? { |modality| modality.healthy?(checked_at) }
  end

  def counts
    @counts ||= {
      tenders: Tender.count,
      open_tenders: Tender.open_for_proposals.count,
      closing_this_week: Tender.closing_within(7).count,
      new_tenders_last_24h: Tender.where(created_at: (checked_at - 24.hours)..).count,
      users: User.count,
      unconfirmed_users: User.where(confirmed_at: nil).count,
      saved_searches: SavedSearch.count,
      notifiable_saved_searches: SavedSearch.notifiable.count,
      notifications_last_24h: Notification.where(sent_at: (checked_at - 24.hours)..).count,
      api_tokens: ApiToken.count
    }
  end

  # Solid Queue's tables live in the primary database (see docs/DEVELOPMENT.md).
  def jobs
    @jobs ||= {
      ready: SolidQueue::ReadyExecution.count,
      scheduled: SolidQueue::ScheduledExecution.count,
      failed: SolidQueue::FailedExecution.count,
      processes: SolidQueue::Process.count
    }
  end

  def recent_runs(limit: 20)
    SyncRun.recent.limit(limit)
  end

  def as_json(*)
    {
      status: healthy? ? "ok" : "degraded",
      checked_at: checked_at.iso8601,
      modalities: modalities.map do |modality|
        {
          id: modality.modality_id,
          name: modality.name,
          healthy: modality.healthy?(checked_at),
          latest_status: modality.latest_run&.status,
          latest_started_at: modality.latest_run&.started_at&.iso8601,
          last_succeeded_at: modality.last_succeeded_at&.iso8601,
          failures_in_a_row: modality.failures_in_a_row
        }
      end,
      counts: counts,
      jobs: jobs
    }
  end
end
