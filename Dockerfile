# Build compilation image
FROM ruby:3.1.0-alpine3.15 as builder

WORKDIR /app

ENV RAILS_ENV=production \
    BUNDLE_APP_CONFIG=/app/vendor/bundle

RUN apk add --update --no-cache build-base \
  git \
  postgresql-dev \
  curl-dev \
  shared-mime-info \
  tzdata && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone

COPY . /app
RUN bundle config path /app/vendor/bundle \
  && bundle install --jobs=4 --no-binstubs

# Build runtime image
FROM ruby:3.1.0-alpine3.15 as production

WORKDIR /app

ENV RAILS_ENV=production \
    BUNDLE_APP_CONFIG=/app/vendor/bundle

RUN apk add --update --no-cache build-base \
  git \
  postgresql-dev \
  curl-dev \
  shared-mime-info \
  tzdata && \
  cp /usr/share/zoneinfo/Europe/London /etc/localtime && \
  echo "Europe/London" > /etc/timezone


# Copy files generated in the builder image
COPY --from=builder /app/ /app

RUN bundle config path /app/vendor/bundle

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
