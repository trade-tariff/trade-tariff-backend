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

      # Mirror trade-tariff-frontend/app/views/search/_interactive_results_content.html.erb:
      # limit results and assign ranks before partitioning by confidence.
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

    # Mirror trade-tariff-frontend/app/controllers/concerns/interactive_searchable.rb
    # (route_interactive_results) and app/models/search/internal_search_result.rb.
    # Keep these rules aligned with frontend routing changes to prevent offer-count drift.
    def self.results_page?(response, interactive, results)
      return true if results.one? && attributes(results.first)[:score].nil?
      return false if pending_question?(interactive)

      intercept = response.dig(:meta, :description_intercept) || {}
      return false if ActiveModel::Type::Boolean.new.cast(intercept[:excluded]) && intercept[:message_header].present? && intercept[:message].present?

      results.any? { |result| (CONFIDENCES - %w[unknown]).include?(attributes(result)[:confidence].to_s.downcase) }
    end

    def self.pending_question?(interactive)
      answers = interactive[:answers]
      answers.present? && answers.last&.[](:answer).blank?
    end

    def self.attributes(result) = result[:attributes] || result
    private_class_method :results_page?, :pending_question?, :attributes
  end
end
