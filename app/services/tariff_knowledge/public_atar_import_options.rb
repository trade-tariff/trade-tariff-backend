module TariffKnowledge
  class PublicAtarImportOptions
    def self.call = new.call

    def call
      {
        limit: integer_env('ATAR_LIMIT', nil),
        max_pages: integer_env('ATAR_MAX_PAGES', 50),
        request_delay: float_env('ATAR_REQUEST_DELAY', PublicAtarRulingSource::DEFAULT_REQUEST_DELAY),
        max_retries: integer_env('ATAR_MAX_RETRIES', PublicAtarRulingSource::DEFAULT_MAX_RETRIES),
      }
    end

  private

    def integer_env(name, default = nil, min: 1)
      value = ENV.fetch(name, default)
      return if value.blank?

      integer = Integer(value, exception: false)
      raise ArgumentError, "#{name} must be an integer" if integer.nil? || integer < min

      integer
    end

    def float_env(name, default, min: 0.0)
      number = Float(ENV.fetch(name, default), exception: false)
      raise ArgumentError, "#{name} must be numeric" if number.nil? || number < min

      number
    end
  end
end
