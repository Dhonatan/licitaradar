module Tenders
  # Searches tenders that are still open for proposals. Built from raw, untrusted params
  # (the search form today, the JSON API and saved searches later): anything invalid is
  # ignored instead of raising.
  #
  #   search = Tenders::Search.new(q: "agência de publicidade", states: %w[ PE PB ], page: 2)
  #   search.results      # => the requested page of Tender records (25 per page)
  #   search.total_count  # => matches across all pages
  #
  # Params:
  # - q: free text in web-search syntax ("frase exata", -excluir, OR). Portuguese
  #   stemming, accents ignored, ranked with ts_rank. Matches the object, additional info,
  #   agency and unit names and — once fetched (Tenders::FetchDetails) — the item
  #   descriptions, which rank lower.
  # - niche: a slug from config/niches.yml; matches any of its keywords (see Niche#tsquery).
  # - states[], modality_ids[]: lists (or comma-separated strings) of UFs / modality ids.
  # - min_value, max_value: estimated value in BRL; accepts "1500", "1500.50", "1.500,50".
  # - closing_within: only tenders whose proposals close in the next N days.
  # - sort: "relevance" (default with q or niche), "closing" (default otherwise) or "value".
  # - page: 1-based page number.
  class Search
    PER_PAGE = 25
    MAX_PAGE = 400
    MAX_QUERY_LENGTH = 200
    MAX_CLOSING_WITHIN = 365
    SORTS = %w[ relevance closing value ].freeze
    CLOSING_WITHIN_OPTIONS = [ 3, 7, 15, 30 ].freeze

    attr_reader :q, :niche, :states, :modality_ids, :min_value, :max_value, :closing_within, :page, :per_page

    def initialize(params = {}, per_page: PER_PAGE)
      params = params.to_h.symbolize_keys

      @q = params[:q].to_s.squish.first(MAX_QUERY_LENGTH).presence
      @niche = Niche.find(params[:niche]) if params[:niche].present?
      @states = list(params[:states]).map(&:upcase).select { |state| BrazilianStates.valid?(state) }.uniq
      @modality_ids = list(params[:modality_ids]).filter_map { |id| integer(id) }.select { |id| Pncp::Modalities.valid?(id) }.uniq
      @min_value, @max_value = [ amount(params[:min_value]), amount(params[:max_value]) ]
      @min_value, @max_value = @max_value, @min_value if @min_value && @max_value && @min_value > @max_value
      @closing_within = integer(params[:closing_within])&.clamp(1, MAX_CLOSING_WITHIN)
      @requested_sort = params[:sort].to_s.presence_in(SORTS)
      @page = (integer(params[:page]) || 1).clamp(1, MAX_PAGE)
      @per_page = per_page
    end

    def sort
      return @requested_sort if @requested_sort && (@requested_sort != "relevance" || text_query?)

      text_query? ? "relevance" : "closing"
    end

    def text_query?
      q.present? || niche.present?
    end

    # Every match, unordered and unpaginated (for counts and further scoping).
    def scope
      relation = Tender.open_for_proposals.in_state(states).of_modality(modality_ids).value_between(min_value, max_value)
      relation = relation.closing_within(closing_within) if closing_within
      relation = relation.where("tenders.searchable @@ websearch_to_tsquery('portuguese', ?)", folded_q) if q
      relation = relation.where("tenders.searchable @@ to_tsquery('portuguese', ?)", niche.tsquery) if niche
      relation
    end

    def results
      @results ||= scope.order(*order_clause).limit(per_page).offset((page - 1) * per_page).to_a
    end

    def total_count
      @total_count ||= scope.count
    end

    def total_pages
      [ (total_count.to_f / per_page).ceil, 1 ].max
    end

    def previous_page
      page - 1 if page > 1
    end

    def next_page
      page + 1 if page < total_pages && page < MAX_PAGE
    end

    def filtered?
      text_query? || states.any? || modality_ids.any? || min_value || max_value || closing_within
    end

    # The normalized params, for links (pagination, "save this search") and forms.
    def to_params(**overrides)
      {
        q: q,
        niche: niche&.slug,
        states: states.presence,
        modality_ids: modality_ids.presence,
        min_value: plain_amount(min_value),
        max_value: plain_amount(max_value),
        closing_within: closing_within,
        sort: @requested_sort
      }.merge(overrides).compact
    end

    private
      def folded_q
        Tender.fold_accents(q)
      end

      def order_clause
        case sort
        when "relevance" then [ Arel.sql(rank_sql), { proposals_close_at: :asc, id: :asc } ]
        when "value" then [ Arel.sql("tenders.estimated_value DESC NULLS LAST"), { proposals_close_at: :asc, id: :asc } ]
        else [ { proposals_close_at: :asc, id: :asc } ]
        end
      end

      def rank_sql
        if q
          Tender.sanitize_sql_array([ "ts_rank(tenders.searchable, websearch_to_tsquery('portuguese', ?)) DESC", folded_q ])
        else
          Tender.sanitize_sql_array([ "ts_rank(tenders.searchable, to_tsquery('portuguese', ?)) DESC", niche.tsquery ])
        end
      end

      def list(value)
        Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).compact_blank
      end

      def integer(value)
        Integer(value.to_s.strip, 10, exception: false)
      end

      # "1500", "1500.50", "1.500", "1.500,50" and "R$ 1.500" are all understood.
      def amount(value)
        text = value.to_s.gsub(/[^\d,.]/, "")
        if text.include?(",")
          text = text.delete(".").tr(",", ".")
        elsif text.match?(/\A\d{1,3}(\.\d{3})+\z/)
          text = text.delete(".")
        end
        BigDecimal(text, exception: false) unless text.empty?
      end

      def plain_amount(number)
        return unless number

        number.frac.zero? ? number.to_i.to_s : number.to_s("F")
      end
  end
end
