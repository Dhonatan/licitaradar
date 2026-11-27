module Tenders
  # Deletes tenders whose proposals closed more than `after_days` days ago (env
  # ARCHIVE_AFTER_DAYS, default 180), so the table, its `raw` jsonb and the backups stop
  # growing with tenders nobody can bid on anymore. Tenders without a closing date count
  # from their last update.
  #
  # Tenders referenced elsewhere are kept, so links in old digests keep working: add every
  # new table that points at tenders to KEPT_WHEN_REFERENCED_BY, unless its
  # rows only describe the tender — tender_documents and tender_items are deleted with it
  # by their foreign keys (ON DELETE CASCADE).
  #
  #   result = Tenders::Archive.new.call
  #   result.deleted_count  # rows removed
  #   result.kept_count     # old enough but referenced, so kept
  class Archive
    DEFAULT_AFTER_DAYS = 180
    BATCH_SIZE = 1_000
    # Models with a tender_id column whose rows keep the tender alive: tenders sent in a
    # digest and tenders someone watches ("Minhas licitações").
    KEPT_WHEN_REFERENCED_BY = [ Notification, Watch ].freeze

    Result = Data.define(:deleted_count, :kept_count, :cutoff)

    # ARCHIVE_AFTER_DAYS, or the default when it is unset or not a positive integer.
    def self.after_days
      days = Integer(ENV.fetch("ARCHIVE_AFTER_DAYS", ""), exception: false)
      days&.positive? ? days : DEFAULT_AFTER_DAYS
    end

    attr_reader :after_days, :cutoff

    def initialize(after_days: self.class.after_days, now: Time.current, batch_size: BATCH_SIZE)
      raise ArgumentError, "after_days must be a positive integer" unless after_days.is_a?(Integer) && after_days.positive?

      @after_days = after_days
      @cutoff = now - after_days.days
      @batch_size = batch_size
    end

    # Tenders old enough to be archived, referenced or not.
    def expired
      Tender.where(proposals_close_at: ...cutoff).or(Tender.where(proposals_close_at: nil, updated_at: ...cutoff))
    end

    # The expired tenders nothing refers to: the ones #call deletes.
    def archivable
      KEPT_WHEN_REFERENCED_BY.reduce(expired) do |scope, model|
        scope.where.not(id: model.select(:tender_id))
      end
    end

    def call
      deleted_count = 0
      # delete_all: no callbacks to run; dependent rows do not exist by construction.
      archivable.in_batches(of: @batch_size) { |batch| deleted_count += batch.delete_all }

      Result.new(deleted_count: deleted_count, kept_count: expired.count, cutoff: cutoff)
    end
  end
end
