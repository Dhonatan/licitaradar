class PagesController < ApplicationController
  # The home page counters run COUNT queries over the open tenders; they change only when
  # the sync runs (every 6 hours), so a few minutes of cache costs nothing.
  COUNTERS_CACHE_KEY = "pages/home/counters"
  COUNTERS_EXPIRE_IN = 5.minutes

  allow_unauthenticated_access

  def home
    @niches = Niche.all
    @open_count, @closing_this_week_count, @last_sync_at = home_counters.values_at(:open, :closing_this_week, :last_sync_at)
    @modalities = Pncp::Modalities::COMPETITIVE.map { |id| [ id, Pncp::Modalities.name_for(id) ] }
  end

  private
    def home_counters
      Rails.cache.fetch(COUNTERS_CACHE_KEY, expires_in: COUNTERS_EXPIRE_IN) do
        {
          open: Tender.open_for_proposals.count,
          closing_this_week: Tender.closing_within(7).count,
          last_sync_at: SyncRun.last_succeeded_at
        }
      end
    end
end
