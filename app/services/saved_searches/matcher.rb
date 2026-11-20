module SavedSearches
  # The tenders a saved search should alert about:
  #
  # 1. they match its criteria, through Tenders::Search (so only tenders still open for
  #    proposals);
  # 2. they were published, updated on the PNCP or first synced by us since the last
  #    notification (`since`, defaults to the search's last_notified_at; nil = no limit,
  #    so the first digest brings every open match);
  # 3. they were never sent for this search before (see Notification).
  #
  #   matcher = SavedSearches::Matcher.new(saved_search)
  #   matcher.tenders(limit: 20)  # most urgent deadlines first
  #   matcher.count
  class Matcher
    CHANGED_SINCE_SQL = <<~SQL.squish.freeze
      tenders.published_at >= :since OR tenders.source_updated_at >= :since OR tenders.created_at >= :since
    SQL

    attr_reader :saved_search, :since

    def initialize(saved_search, since: saved_search.last_notified_at)
      @saved_search = saved_search
      @since = since
    end

    # Every match, unordered (for counts and further scoping).
    def scope
      relation = saved_search.search.scope
      relation = relation.where(CHANGED_SINCE_SQL, since: since) if since
      relation.where.not(id: Notification.where(saved_search_id: saved_search.id).select(:tender_id))
    end

    def tenders(limit: nil)
      relation = scope.order(proposals_close_at: :asc, id: :asc)
      relation = relation.limit(limit) if limit
      relation.to_a
    end

    def count
      scope.count
    end

    def any?
      scope.exists?
    end
  end
end
