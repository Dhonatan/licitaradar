module Watches
  # The private note of a watched tender, edited inline: the note and its form live in a
  # Turbo Frame (on the tender page and on "Minhas licitações"). Without JavaScript the
  # form is a normal page and saving goes back to the tender.
  class NotesController < ApplicationController
    before_action :set_watch

    # The note as shown in its frame ("Cancelar" of the form).
    def show
      return redirect_to tender_path(@tender) unless turbo_frame_request?

      render partial: "watches/notes/note", locals: { watch: @watch }
    end

    def edit
    end

    def update
      if @watch.update(params.expect(watch: [ :note ]))
        return render partial: "watches/notes/note", locals: { watch: @watch } if turbo_frame_request?

        redirect_to tender_path(@tender), notice: "Nota salva."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_watch
        @tender = Tender.find(params[:tender_id])
        @watch = Current.user.watches.find_by!(tender: @tender)
      end
  end
end
