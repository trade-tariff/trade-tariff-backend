# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.2
FROM ruby:$RUBY_VERSION-alpine3.21

RUN apk add --update build-base docker gcompat git gpg postgresql-dev postgresql-client pre-commit python3 openssh shared-mime-info tzdata gnupg
