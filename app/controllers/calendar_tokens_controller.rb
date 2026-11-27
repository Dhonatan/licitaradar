# Creates or replaces the secret token of the user's calendar feed. The previous URL stops
# working at once.
class CalendarTokensController < ApplicationController
  def create
    had_token = Current.user.calendar_token.present?
    Current.user.regenerate_calendar_token

    notice = had_token ? "Novo link do calendário gerado. O link anterior parou de funcionar." : "Link do calendário gerado."
    redirect_to watches_path(anchor: "calendar"), notice: notice, status: :see_other
  end
end
