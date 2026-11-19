# Demo data so the UI works without reaching the PNCP: 30 fictional tenders covering the
# default niches (marketing, events, IT) plus a few others, two of them already closed.
#
#   bin/rails db:seed
#
# Idempotent (rows are keyed by pncp_control_number) and dates are relative to now, so
# re-running it refreshes the deadlines. Agencies, CNPJs and URLs are fictional.
# Skipped in production unless SEED_DEMO_DATA=1.
return if Rails.env.production? && ENV["SEED_DEMO_DATA"].blank?

agencies = {
  exemplopolis: { name: "Prefeitura Municipal de Exemplópolis", cnpj: "00000000000191", city: "Exemplópolis", state: "PE", sphere: "M", power: "E" },
  vila_ficticia: { name: "Câmara Municipal de Vila Fictícia", cnpj: "00000000000272", city: "Vila Fictícia", state: "BA", sphere: "M", power: "L" },
  saude_vila: { name: "Secretaria Municipal de Saúde de Vila Fictícia", cnpj: "00000000000353", city: "Vila Fictícia", state: "BA", sphere: "M", power: "E" },
  comunicacao_estado: { name: "Secretaria de Estado de Comunicação de Exemplo", cnpj: "00000000000434", city: "Cidade Exemplo", state: "MG", sphere: "E", power: "E" },
  cultura: { name: "Fundação de Cultura de Exemplo", cnpj: "00000000000515", city: "São Exemplo", state: "SP", sphere: "E", power: "E" },
  universidade: { name: "Universidade Federal de Exemplo", cnpj: "00000000000604", city: "Porto Exemplo", state: "RS", sphere: "F", power: "E" },
  turismo: { name: "Secretaria de Turismo de Exemplo", cnpj: "00000000000787", city: "Fortaleza Exemplo", state: "CE", sphere: "E", power: "E" },
  instituto: { name: "Instituto Federal de Exemplo", cnpj: "00000000000868", city: "Curitiba Exemplo", state: "PR", sphere: "F", power: "E" },
  sao_joao: { name: "Prefeitura Municipal de São João Fictício", cnpj: "00000000000949", city: "São João Fictício", state: "PB", sphere: "M", power: "E" },
  esportes: { name: "Secretaria de Esportes de Exemplo", cnpj: "00000000001091", city: "Goiânia Exemplo", state: "GO", sphere: "E", power: "E" },
  tribunal: { name: "Tribunal Regional de Exemplo", cnpj: "00000000001172", city: "Brasília", state: "DF", sphere: "F", power: "J" },
  planejamento: { name: "Secretaria de Estado de Planejamento de Exemplo", cnpj: "00000000001253", city: "Florianópolis Exemplo", state: "SC", sphere: "E", power: "E" },
  consorcio: { name: "Consórcio Intermunicipal do Vale Imaginário", cnpj: "00000000001334", city: "Vale Imaginário", state: "MT", sphere: "M", power: "E" }
}

# [ object, agency, modality id, estimated value (0 = confidential), proposals close in (hours) ]
tenders = [
  # Marketing & comunicação
  [ "Contratação de agência de publicidade para prestação de serviços de publicidade institucional e de utilidade pública", :exemplopolis, 4, 4_800_000, 25 * 24 ],
  [ "Gestão de redes sociais e produção de conteúdo digital para os canais oficiais", :vila_ficticia, 6, 180_000, 6 * 24 ],
  [ "Serviços de assessoria de imprensa e comunicação institucional", :comunicacao_estado, 6, 0, 12 * 24 ],
  [ "Produção audiovisual de vídeos institucionais e spots para rádio e TV", :cultura, 6, 350_000, 2 * 24 ],
  [ "Confecção de materiais de comunicação visual: banners, placas e adesivos", :exemplopolis, 8, 45_000, 30 ],
  [ "Campanha publicitária de prevenção à dengue", :saude_vila, 4, 1_200_000, 30 * 24 ],
  [ "Serviços de design gráfico e diagramação de publicações oficiais", :universidade, 6, 95_000, 9 * 24 ],
  [ "Marketing digital e impulsionamento de conteúdo para promoção do turismo", :turismo, 6, 260_000, 15 * 24 ],
  # Eventos
  [ "Organização de eventos institucionais com fornecimento de estrutura, sonorização e iluminação cênica", :exemplopolis, 6, 900_000, 4 * 24 ],
  [ "Serviço de buffet e coffee break para eventos da instituição", :instituto, 6, 120_000, 6 ],
  [ "Locação de palco, montagem de tendas e banheiros químicos para as festividades juninas", :sao_joao, 6, 380_000, 8 * 24 ],
  [ "Credenciamento de apresentações artísticas para o festival de inverno", :cultura, 12, 0, 20 * 24 ],
  [ "Cerimonial e organização de solenidades de formatura", :universidade, 6, 75_000, 11 * 24 ],
  [ "Locação de tendas e estrutura para eventos esportivos", :esportes, 7, 210_000, 5 * 24 ],
  [ "Sonorização e iluminação para eventos da Câmara", :vila_ficticia, 8, 38_000, 3 * 24 ],
  [ "Organização de congresso técnico e eventos paralelos, com hospedagem e alimentação", :tribunal, 6, 640_000, 40 * 24 ],
  # Tecnologia da informação
  [ "Licenças de uso de software de gestão de documentos com suporte técnico", :tribunal, 6, 1_750_000, 14 * 24 ],
  [ "Aquisição de computadores e notebooks para as escolas municipais", :exemplopolis, 6, 2_300_000, 7 * 24 ],
  [ "Desenvolvimento de sistemas sob demanda (fábrica de software)", :planejamento, 4, 0, 35 * 24 ],
  [ "Serviços de computação em nuvem e hospedagem em data center", :universidade, 6, 980_000, 18 * 24 ],
  [ "Cabeamento estruturado e rede lógica do novo prédio administrativo", :instituto, 6, 410_000, 10 * 24 ],
  [ "Outsourcing de impressão com fornecimento de impressoras e suprimentos", :consorcio, 6, 260_000, 2 * 24 ],
  [ "Suporte técnico de informática e manutenção de equipamentos", :vila_ficticia, 8, 52_000, 13 * 24 ],
  [ "Sistema de gestão de saúde pública com implantação e treinamento", :saude_vila, 6, 720_000, 22 * 24 ],
  # Other markets
  [ "Pavimentação asfáltica de vias urbanas", :sao_joao, 4, 3_900_000, 28 * 24 ],
  [ "Serviços de limpeza e conservação predial", :tribunal, 6, 1_100_000, 16 * 24 ],
  [ "Aquisição de gêneros alimentícios para a merenda escolar", :exemplopolis, 6, 0, 5 * 24 ],
  [ "Manutenção do sistema de abastecimento de água", :consorcio, 5, 2_600_000, 24 * 24 ],
  [ "Locação de veículos com motorista", :esportes, 6, 330_000, -2 * 24 ],
  [ "Aquisição de material de expediente", :instituto, 8, 12_000, -24 ]
]

now = Time.current
dispute_modes = { 4 => "Aberto", 5 => "Fechado", 6 => "Aberto", 7 => "Aberto e fechado", 8 => "Não se aplica", 12 => "Não se aplica" }

rows = tenders.each_with_index.map do |(object, agency_key, modality_id, value, close_in_hours), index|
  agency = agencies.fetch(agency_key)
  sequence = index + 1
  close_at = (now + close_in_hours.hours).change(min: 0)
  published_at = close_at - 15.days

  {
    pncp_control_number: "#{agency[:cnpj]}-1-#{sequence.to_s.rjust(6, "0")}/2026",
    year: 2026,
    sequence: sequence,
    purchase_number: sequence.to_s,
    process_number: "2026.#{sequence.to_s.rjust(4, "0")}",
    modality_id: modality_id,
    modality_name: Pncp::Modalities.name_for(modality_id),
    dispute_mode_name: dispute_modes[modality_id],
    status_id: Tender::PUBLISHED_STATUS_ID,
    status_name: "Divulgada no PNCP",
    object_description: object,
    additional_info: "Registro fictício para demonstração do LicitaRadar.",
    price_registration: modality_id == 6 && sequence.even?,
    estimated_value: value,
    proposals_open_at: published_at + 1.day,
    proposals_close_at: close_at,
    published_at: published_at,
    source_updated_at: published_at,
    agency_cnpj: agency[:cnpj],
    agency_name: agency[:name],
    agency_power: agency[:power],
    agency_sphere: agency[:sphere],
    unit_code: "1",
    unit_name: "Departamento de Compras",
    city: agency[:city],
    state: agency[:state],
    origin_url: "https://compras.example.com/processos/2026/#{sequence}",
    pncp_url: nil,
    raw: {},
    last_seen_at: now
  }
end

Tender.upsert_all(rows, unique_by: :pncp_control_number)
puts "Seeded #{rows.size} fictional tenders (#{Tender.open_for_proposals.count} open for proposals)." unless Rails.env.test?
