# Unsubscribe links of the daily digest. The signed token in the URL is the authorization
# (no login needed): a saved search token turns off that search's daily alert, an account
# token turns off every daily alert of the account. Tokens never expire, and the only thing
# they can do is stop e-mails.
#
# GET shows a confirmation button (mail scanners open links, so GET never changes
# anything); POST unsubscribes. Mail providers also POST here for RFC 8058 one-click
# unsubscribes (the List-Unsubscribe-Post header of the digest).
class UnsubscribesController < ApplicationController
  allow_unauthenticated_access
  # One-click POSTs come from mail providers without a CSRF token; the signed token in the
  # URL is what authorizes them.
  skip_forgery_protection only: :create
  before_action :set_saved_searches

  def show
  end

  def create
    @saved_searches.update_all(notify_daily: false, updated_at: Time.current)

    redirect_to unsubscribe_path(params[:token]), notice: "Pronto! Você não vai mais receber esses alertas por e-mail.",
                                                  status: :see_other
  end

  private
    def set_saved_searches
      if (@saved_search = SavedSearch.find_by_token_for(:digest_unsubscribe, params[:token]))
        @saved_searches = SavedSearch.where(id: @saved_search.id)
      elsif (@user = User.find_by_token_for(:digest_unsubscribe_all, params[:token]))
        @saved_searches = @user.saved_searches
      else
        render :invalid, status: :not_found
      end
    end
end
