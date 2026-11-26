ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

Dir[File.expand_path("test_helpers/**/*.rb", __dir__)].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    include RecordsTestHelper
    include EnvTestHelper
    include PncpDetailsTestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Only ActionMailer::TestCase clears the sent e-mails by itself; without this, tests
    # that inspect ActionMailer::Base.deliveries see mail sent by earlier tests in the
    # same worker.
    setup { ActionMailer::Base.deliveries.clear }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
  include ApiTestHelper

  # Rate limits count requests in Rails.cache; start every test from zero.
  setup { Rails.cache.clear }
end
