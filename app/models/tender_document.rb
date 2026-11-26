# A document of a tender on the PNCP (Edital, Termo de Referência, anexos...). Written in
# bulk by Tenders::FetchDetails; attributes mirror Pncp::DocumentNormalizer.
class TenderDocument < ApplicationRecord
  belongs_to :tender

  validates :sequence, presence: true, uniqueness: { scope: :tender_id }
  validates :title, presence: true

  scope :ordered, -> { order(:sequence) }
end
