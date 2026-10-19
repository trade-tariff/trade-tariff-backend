module Search
  class ResultOffers
    CONFIDENCES = %w[strong good possible unlikely unknown].freeze

    def self.record(response:, request_id:)
      return unless TradeTariffBackend.uk?
      return unless TradeTariffRequest.request_source == TradeTariffRequest::FRONTEND_REQUEST_SOURCE
      return if request_id.blank?

      response = response.with_indifferent_access
      interactive = response.dig(:meta, :interactive_search) || {}
      results = Array(response[:data])
      return if interactive[:error].present? || !results_page?(response, interactive, results)

      limit = interactive[:result_limit] || 5
      results = results.first(limit.to_i) unless limit.to_i.zero?
      results.each_with_index do |result, index|
        confidence = attributes(result)[:confidence].to_s.downcase
        confidence = 'unknown' unless CONFIDENCES.include?(confidence)
        Instrumentation.result_offered(request_id:, result_rank: index + 1, confidence:)
      end
    rescue StandardError => e
      Rails.logger.warn("Could not record result offers: #{e.class}")
    end

    # Match the frontend's page routing before applying its display limit.
    def self.results_page?(response, interactive, results)
      return true if results.one? && attributes(results.first)[:score].nil?
      return false if interactive[:answers]&.last&.[](:answer).blank? && interactive[:answers].present?

      intercept = response.dig(:meta, :description_intercept) || {}
      return false if ActiveModel::Type::Boolean.new.cast(intercept[:excluded]) && intercept[:message_header].present? && intercept[:message].present?

      results.any? { |result| (CONFIDENCES - %w[unknown]).include?(attributes(result)[:confidence].to_s.downcase) }
    end

    def self.attributes(result) = result[:attributes] || result
    private_class_method :results_page?, :attributes
  end
end
