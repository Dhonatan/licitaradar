# An item of a tender on the PNCP: what is bought, how much and the estimated values (nil
# when the budget is confidential). Written in bulk by Tenders::FetchDetails; attributes
# mirror Pncp::ItemNormalizer.
class TenderItem < ApplicationRecord
  KINDS = { "M" => "Material", "S" => "Serviço" }.freeze

  belongs_to :tender

  validates :number, presence: true, uniqueness: { scope: :tender_id }

  scope :ordered, -> { order(:number) }

  def kind_name
    KINDS[material_or_service]
  end

  def confidential_value?
    total_estimated_value.nil? && unit_estimated_value.nil?
  end
end
