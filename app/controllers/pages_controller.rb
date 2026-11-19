class PagesController < ApplicationController
  def home
    @niches = Niche.all
    @open_count = Tender.open_for_proposals.count
    @closing_this_week_count = Tender.closing_within(7).count
    @last_sync_at = SyncRun.last_succeeded_at
    @modalities = Pncp::Modalities::COMPETITIVE.map { |id| [ id, Pncp::Modalities.name_for(id) ] }
  end
end
