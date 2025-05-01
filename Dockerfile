# Build compilation image
FROM ruby:3.4.2-alpine3.21 as builder

# The application runs from /app
WORKDIR /app

# build-base: compilation tools for bundle
# git: used to pull gems from git
# yarn: node package manager
RUN apk add --update --no-cache build-base git postgresql-dev shared-mime-info tzdata yaml-dev && \
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
FROM ruby:3.4.2-alpine3.21 as production

# Install PostgreSQL client tools
RUN apk add --no-cache postgresql-client

# Install bash
RUN apk add --no-cache bash

# Install AWS CLI v2
RUN apk add --no-cache \
      curl \
      unzip \
      less \
      groff \
      bash \
      libc6-compat && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

RUN apk add --update --no-cache postgresql-dev curl shared-mime-info tzdata && \
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
