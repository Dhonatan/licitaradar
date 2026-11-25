# Error tracking with Sentry (sentry-ruby + sentry-rails), on only when SENTRY_DSN is set
# (see docs/DEPLOY.md). Without it the gems stay idle and errors only reach the logs.
#
# Errors arrive through ErrorReporting (every Rails.error report) and through
# sentry-rails' own integrations for unhandled exceptions in requests and jobs.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    # No IP addresses, cookies, request bodies or user data: the app's users are people.
    config.send_default_pii = false
    # Performance tracing is off unless asked for (e.g. SENTRY_TRACES_SAMPLE_RATE=0.1).
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0").to_f
    config.breadcrumbs_logger = [ :active_support_logger ]
  end
end
