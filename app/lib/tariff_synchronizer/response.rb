module TariffSynchronizer
  class Response
    TERMINATING_RESPONSE_CODES = [200, 404].freeze

    attr_reader :response_code

    def initialize(response_code, content)
      @response_code = response_code
      @content = content
    end

    def content
      @content.presence || ''
    end

    def terminated?
      response_code.in? TERMINATING_RESPONSE_CODES
    end

    def retry_count_exceeded!
      @retry_count_exceeded = true
    end

    def retry_count_exceeded?
      @retry_count_exceeded
    end

    def state
      if successful?
        :successful
      elsif empty?
        :empty
      elsif retry_count_exceeded?
        :exceeded
      elsif not_found?
        :not_found
      end
    end

  private

    def successful?
      response_code == 200 && @content.present?
    end

    def empty?
      response_code == 200 && @content.empty?
    end

    def not_found?
      response_code == 404
    end
  end
end
