module Pncp
  # Turns one item record of a tender (IntegrationClient#items) into the attributes of
  # a `tender_items` row.
  #
  # The PNCP sends 0 as the estimated values of an item with a confidential budget
  # ("orçamento sigiloso") and no result yet; those become nil, never a free item.
  class ItemNormalizer
    include Values

    def self.call(record)
      new(record).call
    end

    def initialize(record)
      @record = record || {}
    end

    def call
      number = integer(@record["numeroItem"])
      raise InvalidRecord, "item without numeroItem" unless number

      confidential = boolean(@record["orcamentoSigiloso"]) == true
      {
        number: number,
        description: PiiScrubber.call(string(@record["descricao"])),
        material_or_service: string(@record["materialOuServico"])&.upcase&.slice(0, 1),
        quantity: decimal(@record["quantidade"]),
        unit: string(@record["unidadeMedida"]),
        unit_estimated_value: value(@record["valorUnitarioEstimado"], confidential),
        total_estimated_value: value(@record["valorTotal"], confidential),
        confidential_budget: confidential,
        status_name: string(@record["situacaoCompraItemNome"]),
        judgment_criterion_name: string(@record["criterioJulgamentoNome"]),
        benefit_name: string(@record["tipoBeneficioNome"]),
        category_name: string(@record["itemCategoriaNome"]),
        source_updated_at: time(@record["dataAtualizacao"])
      }
    end

    private
      def value(raw, confidential)
        amount = decimal(raw)
        return nil if amount.nil? || amount.negative?
        return nil if confidential && amount.zero?

        amount
      end
  end
end
