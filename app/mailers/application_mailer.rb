class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "LicitaRadar <alertas@licitaradar.example.com>")
  layout "mailer"
end
