require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Licitaradar
  class Application < Rails::Application
    config.load_defaults 8.1

    # lib/ holds framework-independent code (e.g. the PNCP client in lib/pncp).
    # error_reporting.rb is required by its initializer (it is needed while booting).
    config.autoload_lib(ignore: %w[ assets tasks error_reporting.rb ])

    # Brazilian public procurement dates are published in Brasília time.
    config.time_zone = "Brasilia"

    # The UI is in Portuguese. Keys missing from config/locales/pt-BR.yml fall back to
    # Rails' built-in English translations instead of showing "translation missing".
    config.i18n.default_locale = :"pt-BR"
    config.i18n.fallbacks = [ :en ]

    config.generators.system_tests = nil
  end
end
