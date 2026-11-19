# The 27 federative units ("UFs") as used in the PNCP `ufSigla` field.
module BrazilianStates
  ALL = {
    "AC" => "Acre",
    "AL" => "Alagoas",
    "AP" => "Amapá",
    "AM" => "Amazonas",
    "BA" => "Bahia",
    "CE" => "Ceará",
    "DF" => "Distrito Federal",
    "ES" => "Espírito Santo",
    "GO" => "Goiás",
    "MA" => "Maranhão",
    "MT" => "Mato Grosso",
    "MS" => "Mato Grosso do Sul",
    "MG" => "Minas Gerais",
    "PA" => "Pará",
    "PB" => "Paraíba",
    "PR" => "Paraná",
    "PE" => "Pernambuco",
    "PI" => "Piauí",
    "RJ" => "Rio de Janeiro",
    "RN" => "Rio Grande do Norte",
    "RS" => "Rio Grande do Sul",
    "RO" => "Rondônia",
    "RR" => "Roraima",
    "SC" => "Santa Catarina",
    "SP" => "São Paulo",
    "SE" => "Sergipe",
    "TO" => "Tocantins"
  }.freeze

  def self.valid?(code)
    ALL.key?(code.to_s.upcase)
  end

  def self.name_for(code)
    ALL[code.to_s.upcase]
  end
end
