# syntax=docker/dockerfile:1
# check=error=true

# Production image (multi-stage). See docs/DEPLOY.md.
#
#   docker build -t licitaradar .
#   docker run -d -p 3000:3000 \
#     -e DATABASE_URL=postgres://user:password@host:5432/licitaradar_production \
#     -e SECRET_KEY_BASE=$(openssl rand -hex 64) -e APP_HOST=licitaradar.example.com \
#     -e SOLID_QUEUE_IN_PUMA=1 licitaradar
#
# The same image runs the web server (default command) or the job worker (`bin/jobs`).

ARG RUBY_VERSION=3.3.13
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Runtime packages: libpq for the pg gem, jemalloc to keep Ruby's memory in check.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libpq5 libyaml-0-2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away stage to compile gems and assets.
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# The Gemfile reads the Ruby version from .ruby-version.
COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# Propshaft fingerprints app/assets into public/assets. No Node build (import maps).
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final image: runtime packages, gems and the app, running as a non-root user.
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

USER 1000:1000

# Prepares the database (create + schema or migrations) before starting the server.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
