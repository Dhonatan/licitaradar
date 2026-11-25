require "test_helper"

class ErrorReportingTest < ActiveSupport::TestCase
  class FakeForwarder
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(error, **details)
      @calls << [ error, details ]
    end
  end

  class FakeSentry
    attr_reader :captured

    def initialize(initialized:)
      @initialized = initialized
      @captured = []
    end

    def initialized?
      @initialized
    end

    def capture_exception(error, **options)
      @captured << [ error, options ]
    end
  end

  setup do
    @log = StringIO.new
    @forwarder = FakeForwarder.new
    @reporting = ErrorReporting.new(logger: ActiveSupport::Logger.new(@log), forwarder: @forwarder)
  end

  def failure(message = "PNCP fora do ar")
    raise RuntimeError, message
  rescue RuntimeError => error
    error
  end

  test "logs the error with its context and first backtrace lines" do
    @reporting.report(failure, handled: true, severity: :error, context: { modality_id: 6, attempt: 2 }, source: "application")

    assert_match "[ErrorReporting] RuntimeError: PNCP fora do ar (handled=true severity=error source=application)", @log.string
    assert_match 'context={"modality_id":6,"attempt":2}', @log.string
    assert_match "error_reporting_test.rb", @log.string
  end

  test "logs warnings with the warn level" do
    reporting = ErrorReporting.new(logger: ActiveSupport::Logger.new(@log).tap { |logger| logger.level = :warn }, forwarder: @forwarder)

    reporting.report(failure, handled: true, severity: :info, context: {})
    assert_empty @log.string

    reporting.report(failure, handled: true, severity: :warning, context: {})
    assert_match "severity=warning", @log.string
  end

  test "filters personal data and reduces records and jobs to short descriptions" do
    user = create_user(email_address: "ana@example.com")
    job = SendDailyDigestsJob.new

    @reporting.report(failure, handled: true, severity: :error,
                               context: { user: user, email_address: "ana@example.com", job: job, nested: { token: "segredo" } })

    assert_no_match "ana@example.com", @log.string
    assert_no_match "segredo", @log.string
    assert_match "User##{user.id}", @log.string
    assert_match "SendDailyDigestsJob (job #{job.job_id})", @log.string

    _error, details = @forwarder.calls.last
    assert_equal "[FILTERED]", details[:context]["email_address"]
    assert_equal "[FILTERED]", details[:context]["nested"]["token"]
  end

  test "forwards the report" do
    error = failure

    @reporting.report(error, handled: false, severity: :error, context: { user_id: 1 }, source: "application.action_dispatch")

    assert_equal [ [ error, { handled: false, severity: :error, source: "application.action_dispatch", context: { "user_id" => 1 } } ] ],
                 @forwarder.calls
  end

  test "a failing forwarder does not raise" do
    broken = Object.new
    def broken.call(*, **) = raise("Sentry fora do ar")
    reporting = ErrorReporting.new(logger: ActiveSupport::Logger.new(@log), forwarder: broken)

    assert_nothing_raised { reporting.report(failure, handled: true, severity: :error, context: {}) }
    assert_match "could not report RuntimeError: RuntimeError: Sentry fora do ar", @log.string
  end

  test "the Sentry forwarder sends nothing until Sentry is initialized" do
    sentry = FakeSentry.new(initialized: false)

    ErrorReporting::SentryForwarder.new(sentry: sentry).call(failure, handled: true, severity: :error, source: nil, context: {})

    assert_empty sentry.captured
  end

  test "the Sentry forwarder captures the exception with level, tags and context" do
    sentry = FakeSentry.new(initialized: true)
    error = failure

    ErrorReporting::SentryForwarder.new(sentry: sentry).call(error, handled: true, severity: :warning, source: "application",
                                                                    context: { "modality_id" => 6 })

    assert_equal [ [ error, { level: :warning, tags: { handled: true, source: "application" }, contexts: { "rails_error" => { "modality_id" => 6 } } } ] ],
                 sentry.captured
  end

  test "Sentry stays off without SENTRY_DSN" do
    assert_nil ENV["SENTRY_DSN"]
    assert_not Sentry.initialized?
    assert_not ErrorReporting::SentryForwarder.new.enabled?
  end

  test "is subscribed to Rails.error" do
    log = StringIO.new
    test_logger = ActiveSupport::Logger.new(log)
    Rails.logger.broadcast_to(test_logger)

    Rails.error.report(failure("falha de teste"), handled: true, context: { saved_search_id: 42 })

    assert_match(/\[ErrorReporting\] RuntimeError: falha de teste .*"saved_search_id":42/, log.string)
  ensure
    Rails.logger.stop_broadcasting_to(test_logger) if test_logger
  end
end
