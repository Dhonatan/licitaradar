module Pncp
  # "Modalidade de Contratação" domain table (Manual das APIs de Consultas PNCP, 5.2).
  module Modalities
    ALL = {
      1 => "Leilão - Eletrônico",
      2 => "Diálogo Competitivo",
      3 => "Concurso",
      4 => "Concorrência - Eletrônica",
      5 => "Concorrência - Presencial",
      6 => "Pregão - Eletrônico",
      7 => "Pregão - Presencial",
      8 => "Dispensa de Licitação",
      9 => "Inexigibilidade",
      10 => "Manifestação de Interesse",
      11 => "Pré-qualificação",
      12 => "Credenciamento",
      13 => "Leilão - Presencial"
    }.freeze

    # Modalities where a private supplier can actually submit a proposal.
    # These are the ones LicitaRadar syncs by default.
    COMPETITIVE = [ 4, 5, 6, 7, 8, 12 ].freeze

    def self.name_for(id)
      ALL.fetch(id.to_i, "Modalidade #{id}")
    end

    def self.valid?(id)
      ALL.key?(id.to_i)
    end
  end
end
