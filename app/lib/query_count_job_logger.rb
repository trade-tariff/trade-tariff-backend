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
    if args_have_sensitive_data?(item['args'])
      item['args'] = ['[FILTERED]']
    end

    super(item, queue) do
      reset_query_count
      yield
      Sidekiq::Context.add(:queries, query_count)
    end
  end

  private

  def query_count
    ::SequelRails::Railties::LogSubscriber.count
  end

  def reset_query_count
    ::SequelRails::Railties::LogSubscriber.reset_count
  end

  def args_have_sensitive_data?(args)
    return false unless args.is_a?(Array)

    args.any? do |arg|
      arg.is_a?(String) && SENSITIVE_KEYS.any? { |key| arg.downcase.include?(key) }
    end
  end
end
