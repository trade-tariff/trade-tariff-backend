# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-alpine3.20

RUN apk add --update --no-cache gcompat build-base git postgresql-dev shared-mime-info tzdata

CMD ["bin", "dev"]
