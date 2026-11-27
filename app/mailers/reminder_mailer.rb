class ReminderMailer < ApplicationMailer
  helper :tenders

  # watches: the user's watches due for a reminder (Watches::DeadlineReminder), with
  # their tenders loaded, closest deadline first.
  def deadlines(user, watches)
    @user = user
    @watches = watches

    mail to: user.email_address, subject: subject_for(watches)
  end

  private
    def subject_for(watches)
      if watches.one?
        "Prazo de propostas chegando: #{watches.first.tender.object_description.to_s.squish.truncate(70)}"
      else
        "Prazo de propostas chegando em #{watches.size} licitações que você acompanha"
      end
    end
end
