# Preview at http://localhost:3000/rails/mailers/digest_mailer/daily
# Uses the first user, their first saved search and the open tenders in the database
# (`bin/rails db:seed` loads fictional ones); falls back to in-memory examples.
class DigestMailerPreview < ActionMailer::Preview
  def daily
    user = User.take || User.new(email_address: "pessoa@example.com")
    saved_search = user.saved_searches.first || SavedSearch.new(name: "Eventos no Nordeste", niche_slug: "eventos", states: %w[ PE PB ])
    tenders = Tender.open_for_proposals.order(:proposals_close_at).limit(5).to_a.presence || [ example_tender ]
    section = SavedSearches::Digest::Section.new(saved_search: saved_search, tenders: tenders, total_count: tenders.size + 3)

    DigestMailer.daily(user, [ section ])
  end

  private
    def example_tender
      Tender.new(id: 1, pncp_control_number: "00000000000191-1-000001/2026", object_description: "Contratação de empresa para organização de eventos",
                 agency_name: "Prefeitura Municipal de Exemplópolis", city: "Exemplópolis", state: "PE", modality_id: 6,
                 estimated_value: 150_000, proposals_close_at: 3.days.from_now)
    end
end
