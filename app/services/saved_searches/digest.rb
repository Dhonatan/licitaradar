module SavedSearches
  # One user's daily e-mail: for every saved search with daily alerts on, the new matches
  # found by SavedSearches::Matcher (most urgent deadlines first, at most
  # TENDERS_PER_SEARCH per search).
  #
  #   digest = SavedSearches::Digest.new(user)
  #   digest.sections  # => one Section per search that has something new
  #   digest.deliver   # sends the e-mail, records the notifications, moves last_notified_at
  class Digest
    TENDERS_PER_SEARCH = 20

    # total_count counts every new match, including those beyond the e-mail's limit.
    Section = Data.define(:saved_search, :tenders, :total_count) do
      def remaining_count
        total_count - tenders.size
      end
    end

    attr_reader :user, :checked_at

    # now: the moment the matches are looked up; it becomes the searches' last_notified_at,
    # so tenders synced while the digest is being built are picked up by the next one.
    def initialize(user, now: Time.current)
      @user = user
      @checked_at = now
    end

    def saved_searches
      @saved_searches ||= user.saved_searches.notifiable.by_name.to_a
    end

    def sections
      @sections ||= saved_searches.filter_map do |saved_search|
        matcher = Matcher.new(saved_search)
        tenders = matcher.tenders(limit: TENDERS_PER_SEARCH)
        next if tenders.empty?

        total_count = tenders.size < TENDERS_PER_SEARCH ? tenders.size : matcher.count
        Section.new(saved_search: saved_search, tenders: tenders, total_count: total_count)
      end
    end

    def empty?
      sections.empty?
    end

    def tenders_count
      sections.sum(&:total_count)
    end

    # Sends the e-mail when there is something new, then records the tenders it showed (so
    # they are never sent again for the same search) and marks every checked search as
    # notified up to checked_at. Returns true when an e-mail was sent.
    def deliver
      DigestMailer.daily(user, sections).deliver_now unless empty?

      SavedSearch.transaction do
        sections.each { |section| Notification.record!(section.saved_search, section.tenders, sent_at: checked_at) }
        SavedSearch.where(id: saved_searches.map(&:id)).update_all(last_notified_at: checked_at, updated_at: Time.current)
      end

      !empty?
    end
  end
end
