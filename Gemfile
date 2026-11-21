source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.0"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "bootsnap", require: false
gem "bcrypt", "~> 3.1.7" # has_secure_password
gem "solid_queue" # background and recurring jobs, tables in the app's database
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "webmock"
end
