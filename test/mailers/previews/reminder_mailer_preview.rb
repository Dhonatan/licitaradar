# Preview at http://localhost:3000/rails/mailers/reminder_mailer/deadlines
# Uses the first user and open tenders from the database (`bin/rails db:seed` loads
# fictional ones); falls back to an in-memory example.
class ReminderMailerPreview < ActionMailer::Preview
  def deadlines
    user = User.take || User.new(email_address: "pessoa@example.com")
    tenders = Tender.open_for_proposals.order(:proposals_close_at).limit(3).to_a.presence || [ example_tender ]

    ReminderMailer.deadlines(user, tenders.map { |tender| Watch.new(user: user, tender: tender) })
  end

  private
    def example_tender
      Tender.new(id: 1, pncp_control_number: "00000000000191-1-000001/2026", object_description: "Contratação de empresa para organização de eventos",
                 agency_name: "Prefeitura Municipal de Exemplópolis", city: "Exemplópolis", state: "PE", modality_id: 6,
                 estimated_value: 150_000, proposals_close_at: 2.days.from_now)
    end
end
