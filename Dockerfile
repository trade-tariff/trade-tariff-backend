# Build compilation image
FROM ruby:3.2.2-alpine3.18 as builder

# The application runs from /app
WORKDIR /app

# build-base: compilation tools for bundle
# git: used to pull gems from git
# yarn: node package manager
RUN apk add --update --no-cache build-base git postgresql-dev shared-mime-info tzdata && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone

RUN bundle config set without 'development test'

# Install gems defined in Gemfile
COPY .ruby-version Gemfile Gemfile.lock /app/
RUN bundle install --jobs=4 --no-binstubs

# Copy all files to /app (except what is defined in .dockerignore)
COPY . /app/

# Cleanup to save space in the production image
RUN rm -rf node_modules log tmp && \
  rm -rf /usr/local/bundle/cache && \
  rm -rf .env && \
  find /usr/local/bundle/gems -name "*.c" -delete && \
  find /usr/local/bundle/gems -name "*.h" -delete && \
  find /usr/local/bundle/gems -name "*.o" -delete && \
  find /usr/local/bundle/gems -name "*.html" -delete

# Build runtime image
FROM ruby:3.2.2-alpine3.18 as production
ARG DATABASE_USER

RUN apk add --update --no-cache postgresql-dev curl shared-mime-info tzdata && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone

RUN bundle config set without 'development test'

# The application runs from /app
WORKDIR /app

ENV RAILS_ENV=production \
  PORT=8080 \
  GOVUK_APP_DOMAIN="localhost" \
  GOVUK_WEBSITE_ROOT="http://localhost/" \
  DATABASE_URL="postgres://${DATABASE_USER}:@localhost:5432/tariff_development" \
  TARIFF_FROM_EMAIL="test@localhost" \
  TARIFF_SYNC_EMAIL="test@localhost" \
  SECRET_KEY_BASE="8f949e78bd12c534f7d396e28772d1e2b3b744182ac980191f3e62ac25032073ce274fd125cbbeebd0dabc03ccf188f3c3c87bfb3948f037ce4d6f5dec987764" \
  DEFAULT_API_VERSION="2" \
  VCAP_APPLICATION="{}"

# Copy files generated in the builder image
COPY --from=builder /app/ /app
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

HEALTHCHECK CMD nc -z 0.0.0.0 $PORT

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
