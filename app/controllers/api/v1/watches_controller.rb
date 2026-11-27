module Api
  module V1
    # The tenders the token's owner watches ("Minhas licitações"), open ones first by
    # deadline. POST is idempotent: watching a tender twice returns the existing watch
    # (200 instead of 201), with its note replaced when the body has one.
    class WatchesController < BaseController
      def index
        watches = current_user.watches.by_deadline.preload(:tender)
        render json: { data: watches.map { |watch| WatchSerializer.new(watch, self).as_json } }
      end

      def create
        attributes = params.expect(watch: [ :tender_id, :note ])
        tender = Tender.find(attributes[:tender_id])
        watch = current_user.watches.find_or_initialize_by(tender: tender)
        status = watch.new_record? ? :created : :ok
        watch.note = attributes[:note] if attributes.key?(:note)

        if watch.save
          render json: { data: WatchSerializer.new(watch, self).as_json }, status: status, location: api_v1_watch_url(watch)
        else
          render_error :unprocessable_content, "invalid", watch.errors.full_messages.to_sentence, details: watch.errors.to_hash
        end
      rescue ActiveRecord::RecordNotUnique
        retry # a concurrent request created it: answer with that one
      end

      def destroy
        current_user.watches.find(params[:id]).destroy
        head :no_content
      end
    end
  end
end
