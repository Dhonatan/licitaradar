# The deadline reminder setting of "Minha conta": how many days before the proposals
# deadline of a watched tender the reminder e-mail goes out (or off).
class ReminderSettingsController < ApplicationController
  def update
    user = Current.user

    if user.update(params.expect(user: [ :deadline_reminder_days ]))
      redirect_to account_path(anchor: "deadline-reminders"), notice: reminder_notice(user)
    else
      redirect_to account_path(anchor: "deadline-reminders"), alert: "Escolha uma das opções de lembrete."
    end
  end

  private
    def reminder_notice(user)
      if user.deadline_reminders?
        "Lembretes ativados: você recebe um e-mail #{user.deadline_reminder_days == 1 ? "1 dia" : "#{user.deadline_reminder_days} dias"} antes do prazo das licitações que acompanha."
      else
        "Lembretes de prazo desligados."
      end
    end
end
