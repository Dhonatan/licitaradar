class TendersController < ApplicationController
  allow_unauthenticated_access

  def index
    @search = Tenders::Search.new(search_params)
  end

  def show
    @tender = Tender.find(params[:id])
  end

  private
    # Lists also accept a comma-separated string (?states=PE,PB), see Tenders::Search.
    def search_params
      params.permit(:q, :niche, :min_value, :max_value, :closing_within, :sort, :page, :states, :modality_ids,
                    states: [], modality_ids: [])
    end
end
