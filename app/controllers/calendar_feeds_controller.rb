# The iCalendar feed of a user's watched deadlines (/calendario/:token.ics), subscribed to
# by calendar apps, which cannot log in: the secret token in the URL is the only
# authorization. It shows which tenders the user watches (public data), never the notes;
# "Gerar novo link" (CalendarTokensController) replaces a leaked token.
class CalendarFeedsController < ApplicationController
  allow_unauthenticated_access

  def show
    user = User.find_by(calendar_token: params[:token]) if params[:token].present?
    return head(:not_found) unless user

    send_data Watches::Calendar.new(user, urls: self).to_ics, type: "text/calendar; charset=utf-8",
                                                               disposition: "inline", filename: "licitaradar.ics"
  end
end
