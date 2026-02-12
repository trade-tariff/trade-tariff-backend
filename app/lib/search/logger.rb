require 'active_support/log_subscriber'

module Search
  class Logger < ActiveSupport::LogSubscriber
    def search_started(event)
      info log_entry(
        event: 'search_started',
        request_id: event.payload[:request_id],
        query: event.payload[:query],
        search_type: event.payload[:search_type],
      )
    end

    def query_expanded(event)
      info log_entry(
        event: 'query_expanded',
        request_id: event.payload[:request_id],
        original_query: event.payload[:original_query],
        expanded_query: event.payload[:expanded_query],
        reason: event.payload[:reason],
        duration_ms: event.payload[:duration_ms],
      )
    end

    def api_call_completed(event)
      info log_entry(
        event: 'api_call_completed',
        request_id: event.payload[:request_id],
        model: event.payload[:model],
        duration_ms: event.payload[:duration_ms],
        response_type: event.payload[:response_type],
        attempt_number: event.payload[:attempt_number],
      )
    end

    def question_returned(event)
      info log_entry(
        event: 'question_returned',
        request_id: event.payload[:request_id],
        question_count: event.payload[:question_count],
        attempt_number: event.payload[:attempt_number],
      )
    end

    def answer_returned(event)
      info log_entry(
        event: 'answer_returned',
        request_id: event.payload[:request_id],
        answer_count: event.payload[:answer_count],
        confidence_levels: event.payload[:confidence_levels],
        attempt_number: event.payload[:attempt_number],
      )
    end

    def search_completed(event)
      data = {
        event: 'search_completed',
        request_id: event.payload[:request_id],
        query: event.payload[:query],
        search_type: event.payload[:search_type],
        total_attempts: event.payload[:total_attempts],
        total_questions: event.payload[:total_questions],
        final_result_type: event.payload[:final_result_type],
        total_duration_ms: event.payload[:total_duration_ms],
        result_count: event.payload[:result_count],
      }
      data[:results_type] = event.payload[:results_type] if event.payload[:results_type]
      data[:max_score] = event.payload[:max_score] if event.payload[:max_score]
      info log_entry(data)
    end

    def result_selected(event)
      info log_entry(
        event: 'result_selected',
        request_id: event.payload[:request_id],
        goods_nomenclature_item_id: event.payload[:goods_nomenclature_item_id],
        goods_nomenclature_class: event.payload[:goods_nomenclature_class],
      )
    end

    def search_failed(event)
      error log_entry(
        event: 'search_failed',
        request_id: event.payload[:request_id],
        error_type: event.payload[:error_type],
        error_message: event.payload[:error_message],
        search_type: event.payload[:search_type],
      )
    end

    private

    def log_entry(data)
      data.merge(
        service: 'search',
        timestamp: Time.current.iso8601,
      ).to_json
    end
  end
end

Search::Logger.attach_to :search unless Rails.env.test?
