require 'sidekiq/component'
require 'sidekiq/job_logger'

class QueryCountJobLogger < ::Sidekiq::JobLogger
  SENSITIVE_KEYS = %w[
    email
    password
    passw
    token
    secret
    api_key
    key
    otp
    ssn
    cvc
    cvv
  ].freeze

  def call(item, queue)
    super do
      reset_query_count

      yield

      Sidekiq::Context.add(:queries, query_count)
    rescue StandardError
      item.replace(redact_if_sensitive(item))
      raise
    end
  end

  private

  def query_count
    ::SequelRails::Railties::LogSubscriber.count
  end

  def reset_query_count
    ::SequelRails::Railties::LogSubscriber.reset_count
  end

  def redact_if_sensitive(item)
    return item unless sensitive_args?(item['args'])

    item.dup.tap do |copy|
      copy['args'] = ['[FILTERED]']
    end
  end

  def sensitive_args?(args)
    return false unless args.is_a?(Array)

    args.any? do |arg|
      arg.is_a?(String) && SENSITIVE_KEYS.any? { |key| arg.downcase.include?(key) }
    end
  end
end
