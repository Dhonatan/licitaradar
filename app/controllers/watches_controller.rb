# "Minhas licitações" (the tenders the user follows) and the "Acompanhar" button of the
# tender page and the results (POST/DELETE /tenders/:tender_id/watch, answered with a
# Turbo Stream that swaps the button).
class WatchesController < ApplicationController
  before_action :set_tender, only: %i[ show create destroy ]

  def index
    @watches = Current.user.watches.by_deadline.preload(:tender)
  end

  # Signed-out visitors click "Acompanhar" here: they log in and come back to the tender.
  def show
    redirect_to tender_path(@tender)
  end

  def create
    @watch = Watch.watch!(Current.user, @tender)
    @error = @watch.errors.full_messages.to_sentence.presence
    @watch = nil if @error

    respond_with_button notice: ("Você está acompanhando esta licitação." unless @error)
  end

  def destroy
    Current.user.watches.where(tender: @tender).destroy_all
    @watch = nil

    respond_with_button notice: "Você deixou de acompanhar esta licitação."
  end

  private
    def set_tender
      @tender = Tender.find(params[:tender_id])
    end

    def respond_with_button(notice:)
      respond_to do |format|
        format.turbo_stream { render :toggle }
        format.html { redirect_back_or_to tender_path(@tender), notice: notice, alert: @error, status: :see_other }
      end
    end
end
