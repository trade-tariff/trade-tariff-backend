# frozen_string_literal: true

module SearchExport
  class JourneyProjection
    TRACE_VERSION = 'classification_evaluation_trace.v2'

    def self.record(response:, query:, answers:, expansion_terms:, request_id:, terminal_at: Time.current)
      return unless TradeTariffBackend.uk?
      return unless TradeTariffRequest.request_source == TradeTariffRequest::FRONTEND_REQUEST_SOURCE
      return if request_id.blank?

      if TradeTariffRequest.search_failures.present? || interactive_error?(response)
        Journey.omit(request_id)
        return
      end

      page = TerminalPage.from_response(response)
      return unless page

      Journey.upsert_terminal(
        request_id:,
        service: TradeTariffBackend.service,
        request_source: TradeTariffRequest::FRONTEND_REQUEST_SOURCE,
        query: query.to_s,
        expansion_terms: Sequel.pg_jsonb(Array(expansion_terms)),
        answers: Sequel.pg_jsonb(normalised_answers(answers)),
        end_page_type: page.end_page_type,
        results: Sequel.pg_jsonb(page.results.map { |result| result.to_h.transform_keys(&:to_s) }),
        terminal_at:,
      )
      emit_trace(request_id:, query:, answers:, expansion_terms:, page:, terminal_at:)
    rescue StandardError => e
      Rails.logger.warn("Could not capture classifier journey: #{e.class}")
      nil
    end

    def self.omit(request_id)
      return unless TradeTariffBackend.uk?
      return unless TradeTariffRequest.request_source == TradeTariffRequest::FRONTEND_REQUEST_SOURCE

      Journey.omit(request_id)
    rescue StandardError => e
      Rails.logger.warn("Could not omit classifier journey: #{e.class}")
      nil
    end

    def self.interactive_error?(response)
      interactive = response&.dig(:meta, :interactive_search) || response&.dig('meta', 'interactive_search') || {}
      (interactive[:error] || interactive['error']).present?
    end

    def self.normalised_answers(answers)
      Array(answers).map do |answer|
        values = answer.to_h
        {
          'question' => values[:question] || values['question'],
          'options' => Array(values[:options] || values['options']),
          'answer' => values[:answer] || values['answer'],
        }
      end
    end

    def self.emit_trace(request_id:, query:, answers:, expansion_terms:, page:, terminal_at:)
      ::Search::Instrumentation.evaluation_journey_recorded(
        request_id:,
        query: query.to_s,
        expansion_terms: Array(expansion_terms),
        answers: normalised_answers(answers),
        end_page_type: page.end_page_type,
        results: page.results.map(&:to_h),
        terminal_at: terminal_at.iso8601,
        trace_version: TRACE_VERSION,
      )
    end
    private_class_method :normalised_answers, :emit_trace
  end
end
