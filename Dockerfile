# Build compilation image
ARG RUBY_VERSION=3.4.7
ARG ALPINE_VERSION=3.22

FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION} AS builder

# The application runs from /app
WORKDIR /app

# build-base: compilation tools for bundle
# git: used to pull gems from git
# yarn: node package manager
RUN apk add \
  --update \
  --no-cache \
  build-base \
  git \
  shared-mime-info \
  tzdata \
  postgresql-dev \
  zlib-dev \
  yaml-dev \
  && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone

# Install gems defined in Gemfile
RUN bundle config set without 'development test'
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

FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION} AS production

# Install required packages in one layer
RUN apk add --no-cache \
    bash \
    curl \
    postgresql-client \
    postgresql-dev \
    aws-cli \
    shared-mime-info \
    socat \
    tzdata && \
    cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
    echo "Europe/London" > /etc/timezone

RUN bundle config set without 'development test'

# The application runs from /app
WORKDIR /app

ENV RAILS_ENV=production \
  PORT=8080

# Copy files generated in the builder image
COPY --from=builder /app/ /app
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

RUN bundle config set without 'development test'

RUN addgroup -S tariff && \
  adduser -S tariff -G tariff && \
  chown -R tariff:tariff /app && \
  chown -R tariff:tariff /usr/local/bundle

HEALTHCHECK CMD nc -z 0.0.0.0 $PORT

USER tariff

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
