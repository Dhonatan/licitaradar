Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?

  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.com" }

  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true

  # CI builds the test database with `db:create db:migrate` (see .github/workflows/ci.yml),
  # so db/schema.rb is regenerated there instead of being loaded from a possibly stale copy.
  config.active_record.maintain_test_schema = false
end
