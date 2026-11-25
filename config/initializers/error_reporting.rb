# Log (and forward to Sentry when configured) everything reported to Rails.error.
require Rails.root.join("lib/error_reporting").to_s

Rails.error.subscribe(ErrorReporting.new)
