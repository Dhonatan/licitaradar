# A search a user saved to get alerts about. The criteria are the Tenders::Search params:
# `query` (q), `niche_slug` (niche) and the remaining filters in the `filters` jsonb
# (states, modality_ids, min_value, max_value, closing_within). They are normalized by
# Tenders::Search before validation, so what is stored is exactly what the search uses.
#
#   saved_search = user.saved_searches.create!(query: "buffet", states: %w[ PE ])
#   saved_search.search.results   # => the open tenders it matches right now
class SavedSearch < ApplicationRecord
  MAX_PER_USER = 20
  MAX_NAME_LENGTH = 100
  FILTER_KEYS = %w[ states modality_ids min_value max_value closing_within ].freeze

  belongs_to :user

  FILTER_KEYS.each do |key|
    define_method(key) { filter_values[key] }
    define_method(:"#{key}=") { |value| self.filters = filter_values.merge(key => value) }
  end

  normalizes :name, with: ->(name) { name.squish }

  before_validation :normalize_criteria
  before_validation :assign_default_name

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :niche_must_exist
  validate :criteria_must_be_present
  validate :saved_searches_per_user_limit, on: :create

  scope :active, -> { where(active: true) }
  scope :notifiable, -> { active.where(notify_daily: true) }
  scope :by_name, -> { order(Arel.sql("lower(saved_searches.name)"), :id) }

  # Builds a saved search from Tenders::Search-style params (q, niche, states, ...),
  # e.g. the query string of the results page that the "Salvar esta busca" button sends.
  def self.from_search_params(params, **attributes)
    search = Tenders::Search.new(params)
    new(query: search.q, niche_slug: search.niche&.slug, **search.to_params.slice(*FILTER_KEYS.map(&:to_sym)), **attributes)
  end

  def niche
    Niche.find(niche_slug) if niche_slug.present?
  end

  # The params Tenders::Search (and links to the results page) understand.
  def search_params
    { q: query, niche: niche_slug }.merge(filter_values.slice(*FILTER_KEYS).symbolize_keys).compact_blank
  end

  def search(**overrides)
    Tenders::Search.new(search_params.merge(overrides))
  end

  # "“buffet” · Eventos · PE, PB" — used when the user does not name the search.
  def suggested_name
    parts = [ ("“#{query}”" if query.present?), niche&.name, Array(states).join(", ").presence ].compact
    parts.join(" · ").presence&.truncate(MAX_NAME_LENGTH) || "Minha busca"
  end

  private
    def filter_values
      filters.to_h.stringify_keys
    end

    def normalize_criteria
      search = Tenders::Search.new(q: query, states: states, modality_ids: modality_ids, min_value: min_value,
                                   max_value: max_value, closing_within: closing_within)
      self.query = search.q
      self.niche_slug = niche_slug.to_s.strip.presence
      self.filters = search.to_params.slice(*FILTER_KEYS.map(&:to_sym)).deep_stringify_keys
    end

    def assign_default_name
      self.name = suggested_name if name.blank?
    end

    def niche_must_exist
      errors.add(:niche_slug, :inclusion) if niche_slug.present? && niche.nil?
    end

    def criteria_must_be_present
      return if query.present? || niche_slug.present? || filter_values.values.any?(&:present?)

      errors.add(:base, "Escolha pelo menos uma palavra-chave, nicho ou filtro para salvar a busca.")
    end

    def saved_searches_per_user_limit
      return unless user && user.saved_searches.count >= MAX_PER_USER

      errors.add(:base, "Você já tem #{MAX_PER_USER} buscas salvas, o máximo por conta. Exclua uma para salvar outra.")
    end
end
