module SavedSearchesHelper
  # Human-readable criteria of a saved search, one string per criterion.
  def saved_search_criteria(saved_search)
    [
      ("Palavras-chave: #{saved_search.query}" if saved_search.query.present?),
      ("Nicho: #{saved_search.niche.name}" if saved_search.niche),
      ("Estados: #{Array(saved_search.states).join(", ")}" if saved_search.states.present?),
      ("Modalidades: #{Array(saved_search.modality_ids).map { |id| Pncp::Modalities.name_for(id) }.compact.join(", ")}" if saved_search.modality_ids.present?),
      saved_search_value_range(saved_search),
      ("Encerra em até #{saved_search.closing_within} dias" if saved_search.closing_within.present?)
    ].compact
  end

  private
    def saved_search_value_range(saved_search)
      min = saved_search.min_value.presence && brl(BigDecimal(saved_search.min_value))
      max = saved_search.max_value.presence && brl(BigDecimal(saved_search.max_value))

      if min && max then "Valor estimado: de #{min} a #{max}"
      elsif min then "Valor estimado: a partir de #{min}"
      elsif max then "Valor estimado: até #{max}"
      end
    end
end
