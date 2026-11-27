class TendersController < ApplicationController
  include CsvStreaming

  allow_unauthenticated_access
  # The CSV export of the results (up to Tenders::CsvExport::MAX_ROWS) is for signed-in users.
  before_action :require_authentication, only: :index, if: :csv_request?
  rate_limit to: 20, within: 10.minutes, only: :index, if: :csv_request?, by: -> { Current.user.id },
             with: -> { redirect_to tenders_path, alert: "Muitas exportações seguidas. Aguarde alguns minutos e tente de novo." }

  # The "tender_details" frame reloads itself every few seconds while the documents and
  # items are being fetched, up to this many times (about a minute).
  MAX_DETAILS_POLLS = 20
  # Tenders can have thousands of items; the page shows the first ones.
  ITEMS_SHOWN = 100

  def index
    @search = Tenders::Search.new(search_params)

    respond_to do |format|
      format.html { @watched_tender_ids = watched_tender_ids(@search.results) }
      format.csv do
        stream_csv Tenders::CsvExport.new(@search.ordered_scope, urls: self), filename: "licitacoes-abertas-#{Date.current.iso8601}.csv"
      end
    end
  end

  def show
    @tender = Tender.find(params[:id])
    @watch = Current.user.watches.find_by(tender: @tender) if authenticated?
  end

  # Turbo Frame content: the documents and items, or a loading state that polls while
  # FetchTenderDetailsJob runs. Opening it is what triggers the first fetch (and a refresh
  # when the tender changed on the PNCP), so crawlers that skip frames fetch nothing.
  def details
    @tender = Tender.find(params[:id])
    @tender.request_details_fetch
    @poll = params[:poll].to_i.clamp(0, MAX_DETAILS_POLLS)
    return unless @tender.details_fetched?

    @documents = @tender.documents.to_a
    @items = @tender.items.limit(ITEMS_SHOWN).to_a
    @items_count = @items.size < ITEMS_SHOWN ? @items.size : @tender.items.count
  end

  private
    def csv_request?
      request.format.csv?
    end

    # The tenders of the page the signed-in user watches (one query), for the "Acompanhar" buttons.
    def watched_tender_ids(tenders)
      return Set.new unless authenticated?

      Current.user.watches.where(tender_id: tenders.map(&:id)).pluck(:tender_id).to_set
    end

    # Lists also accept a comma-separated string (?states=PE,PB), see Tenders::Search.
    def search_params
      params.permit(:q, :niche, :min_value, :max_value, :closing_within, :sort, :page, :states, :modality_ids,
                    states: [], modality_ids: [])
    end
end
