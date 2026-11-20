# Small factories shared by the test suite. Data is fictional (example.com addresses,
# CNPJ 00000000000191).
module RecordsTestHelper
  DEFAULT_PASSWORD = "senha-secreta-123".freeze

  def create_user(email_address: nil, password: DEFAULT_PASSWORD)
    @user_sequence = @user_sequence.to_i + 1
    User.create!(email_address: email_address || "pessoa#{@user_sequence}@example.com", password: password)
  end

  # Named differently from the create_tender helpers some older tests define locally.
  def create_open_tender(**attributes)
    @open_tender_sequence = @open_tender_sequence.to_i + 1
    Tender.create!({
      pncp_control_number: "00000000000191-1-#{(900_000 + @open_tender_sequence).to_s.rjust(6, "0")}/2026",
      modality_id: 6,
      modality_name: "Pregão - Eletrônico",
      status_id: Tender::PUBLISHED_STATUS_ID,
      status_name: "Divulgada no PNCP",
      state: "PE",
      city: "Exemplópolis",
      agency_name: "Prefeitura Municipal de Exemplópolis",
      agency_cnpj: "00000000000191",
      object_description: "Aquisição de material de expediente",
      estimated_value: 10_000,
      published_at: 1.day.ago,
      proposals_close_at: 10.days.from_now
    }.merge(attributes))
  end
end
