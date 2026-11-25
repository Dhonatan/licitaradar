# Subscriber of Rails' error reporter (`Rails.error`), registered in
# config/initializers/error_reporting.rb. Every report — handled errors the app reports
# itself (a failing sync modality, a digest that failed for one user) and the unhandled
# exceptions Rails reports for requests and jobs — is logged with its context and, when
# Sentry is configured (SENTRY_DSN), forwarded to it.
#
# Context values are reduced to plain data (records and jobs become short descriptions)
# and keys matching config.filter_parameters (e-mail, token, password...) are filtered
# before they are logged or sent anywhere.
#
# This file is required by the initializer instead of being autoloaded (see
# config/application.rb): reloadable code cannot be used while the app boots.
class ErrorReporting
  LOG_LEVELS = { error: :error, warning: :warn, info: :info }.freeze
  BACKTRACE_LINES = 5

  # Sends reports to Sentry once `Sentry.init` ran (config/initializers/sentry.rb). Sentry
  # marks the exceptions it captured, so an error also caught by sentry-rails' own
  # request/job integrations is not sent twice.
  class SentryForwarder
    def initialize(sentry: (::Sentry if defined?(::Sentry)))
      @sentry = sentry
    end

    def enabled?
      !@sentry.nil? && @sentry.initialized?
    end

    def call(error, handled:, severity:, source:, context:)
      return unless enabled?

      @sentry.capture_exception(error, level: severity, tags: { handled: handled, source: source }.compact,
                                       contexts: { "rails_error" => context })
    end
  end

  def initialize(logger: nil, forwarder: SentryForwarder.new)
    @logger = logger
    @forwarder = forwarder
  end

  # The interface Rails.error calls (ActiveSupport::ErrorReporter).
  def report(error, handled:, severity:, context:, source: nil)
    context = filtered(context)
    logger.public_send(LOG_LEVELS.fetch(severity, :error), log_message(error, handled:, severity:, source:, context:))
    @forwarder.call(error, handled: handled, severity: severity, source: source, context: context)
  rescue StandardError => reporting_error
    # Reporting must never break the code that reported the error.
    logger.error "[ErrorReporting] could not report #{error.class}: #{reporting_error.class}: #{reporting_error.message}"
  end

  private
    def logger
      @logger || Rails.logger
    end

    def filtered(context)
      parameter_filter.filter(plain(context.to_h))
    end

    # Built on first use: config.filter_parameters is filled by a later initializer.
    def parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    def plain(value)
      case value
      when Hash then value.to_h { |key, item| [ key.to_s, plain(item) ] }
      when Array then value.first(20).map { |item| plain(item) }
      when String, Symbol, Numeric, true, false, nil then value
      when Time, Date, DateTime, ActiveSupport::TimeWithZone then value.iso8601
      when ActiveRecord::Base then "#{value.class.name}##{value.id}"
      when ActiveJob::Base then "#{value.class.name} (job #{value.job_id})"
      when ActionController::Metal then "#{value.class.name}##{value.action_name}"
      else value.class.name
      end
    end

    def log_message(error, handled:, severity:, source:, context:)
      details = { handled: handled, severity: severity, source: source }.compact.map { |key, value| "#{key}=#{value}" }.join(" ")
      lines = [ "[ErrorReporting] #{error.class}: #{error.message} (#{details}) context=#{context.to_json}" ]
      lines.concat(Array(error.backtrace).first(BACKTRACE_LINES).map { |line| "  #{line}" })
      lines.join("\n")
    end
end
