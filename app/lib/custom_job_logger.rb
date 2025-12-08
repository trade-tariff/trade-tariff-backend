require 'sidekiq/component'
require 'sidekiq/job_logger'

class CustomJobLogger < ::Sidekiq::JobLogger
  SENSITIVE_KEYS = %w[
    email password passw token secret api_key key otp ssn cvc cvv
  ].freeze

  def call(item, queue)
    start = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    reset_query_count
    yield
    duration = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start

    Sidekiq.logger.info(
      'class' => item['class'],
      'jid' => item['jid'],
      'queue' => queue,
      'args' => redact_args(item['args']),
      'duration' => duration,
      'queries' => query_count,
      'status' => 'done',
    )
  rescue StandardError => e
    duration = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start

    Sidekiq.logger.warn(
      'class' => item['class'],
      'jid' => item['jid'],
      'queue' => queue,
      'args' => redact_args(item['args']),
      'duration' => duration,
      'queries' => query_count,
      'status' => 'fail',
      'error_class' => e.class.name,
      'error_message' => e.message,
    )

    raise e
  end

  private

  def query_count
    ::SequelRails::Railties::LogSubscriber.count
  end

  def reset_query_count
    ::SequelRails::Railties::LogSubscriber.reset_count
  end

  def redact_args(args)
    return args unless sensitive_args?(args)

    ['[FILTERED]']
  end

  def sensitive_args?(args)
    return false unless args.is_a?(Array)

    args.any? do |arg|
      arg.is_a?(String) && SENSITIVE_KEYS.any? { |key| arg.downcase.include?(key) }
    end
  end
end
