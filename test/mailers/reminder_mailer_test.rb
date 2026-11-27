require "test_helper"
require Rails.root.join("test/mailers/previews/reminder_mailer_preview").to_s

class ReminderMailerTest < ActionMailer::TestCase
  setup do
    @user = create_user(email_address: "ana@example.com")
  end

  test "deadlines lists the watched tenders with deadline, value and links" do
    tender = create_open_tender(object_description: "Serviço de buffet para formatura", agency_name: "Prefeitura de Exemplópolis",
                                estimated_value: 12_345.6, proposals_close_at: 3.days.from_now.change(hour: 14, min: 0))
    secret = create_open_tender(object_description: "Locação de palco", estimated_value: 0, proposals_close_at: 1.day.from_now.change(hour: 9))
    watches = [ secret, tender ].map { |watched| Watch.watch!(@user, watched) }

    mail = ReminderMailer.deadlines(@user, watches)

    assert_equal [ "ana@example.com" ], mail.to
    assert_equal "Prazo de propostas chegando em 2 licitações que você acompanha", mail.subject
    [ mail.html_part.body.to_s, mail.text_part.body.to_s ].each do |body|
      assert_includes body, "2 licitações que você acompanha"
      assert_includes body, "Serviço de buffet para formatura"
      assert_includes body, "Prefeitura de Exemplópolis"
      assert_includes body, "Encerra em 3 dias"
      assert_includes body, "Encerra amanhã"
      assert_includes body, "R$ 12.345,60"
      assert_includes body, "Valor sigiloso"
      assert_includes body, "http://example.com/tenders/#{tender.id}"
      assert_includes body, "http://example.com/minhas-licitacoes"
      assert_includes body, "http://example.com/account#deadline-reminders"
      assert_includes body, "3 dias antes do prazo"
    end
  end

  test "deadlines includes the private note" do
    watch = Watch.watch!(@user, create_open_tender(object_description: "Serviço de buffet"))
    watch.update!(note: "Levar amostras na sessão")

    mail = ReminderMailer.deadlines(@user, [ watch ])

    assert_includes mail.text_part.body.to_s, "Sua nota: Levar amostras na sessão"
    assert_includes mail.html_part.body.to_s, "Levar amostras na sessão"
  end

  test "a single tender is named in the subject" do
    watch = Watch.watch!(@user, create_open_tender(object_description: "Serviço de buffet para formatura"))

    assert_equal "Prazo de propostas chegando: Serviço de buffet para formatura", ReminderMailer.deadlines(@user, [ watch ]).subject
  end

  test "the preview renders" do
    assert_includes ReminderMailerPreview.new.deadlines.text_part.body.to_s, "prazo de propostas chegando"
  end
end
