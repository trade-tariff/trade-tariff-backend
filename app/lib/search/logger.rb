require 'active_support/log_subscriber'

module Search
  class Logger < ActiveSupport::LogSubscriber
    def search_started(event)
      info log_entry({
        event: 'search_started',
        request_id: event.payload[:request_id],
        query: event.payload[:query],
        search_type: event.payload[:search_type],
      }, event)
    end

    def query_expanded(event)
      info log_entry({
        event: 'query_expanded',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        original_query: event.payload[:original_query],
        expanded_query: event.payload[:expanded_query],
        reason: event.payload[:reason],
        duration_ms: event.payload[:duration_ms],
      }, event)
    end

    def query_refined(event)
      info log_entry({
        event: 'query_refined',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        base_query: event.payload[:base_query],
        original_query: event.payload[:original_query],
        refined_query: event.payload[:refined_query],
        effective_query: event.payload[:effective_query],
        answer_count: event.payload[:answer_count],
        added_answers: event.payload[:added_answers],
        iteration: event.payload[:iteration],
      }, event)
    end

    def query_expansion_decided(event)
      info log_entry({
        event: 'query_expansion_decided',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        expand: event.payload[:expand],
        reason: event.payload[:reason],
        decider_version: event.payload[:decider_version],
        result_count: event.payload[:result_count],
        max_score: event.payload[:max_score],
      }, event)
    end

    def query_expansion_timed_out(event)
      info log_entry({
        event: 'query_expansion_timed_out',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        timeout_ms: event.payload[:timeout_ms],
        elapsed_ms: event.payload[:elapsed_ms],
        model: event.payload[:model],
        fallback_outcome: event.payload[:fallback_outcome],
      }, event)
    end

    def api_call_completed(event)
      data = {
        event: 'api_call_completed',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        model: event.payload[:model],
        duration_ms: event.payload[:duration_ms],
        response_type: event.payload[:response_type],
        attempt_number: event.payload[:attempt_number],
        iteration: event.payload[:iteration],
        effective_query: event.payload[:effective_query],
        operation: event.payload[:operation],
      }
      add_ai_usage_fields!(data, event)
      add_error_fields!(data, event)
      info log_entry(data, event)
    end

    def exact_match_selected(event)
      info log_entry({
        event: 'exact_match_selected',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        match_source: event.payload[:match_source],
        matched_value: event.payload[:matched_value],
        target_type: event.payload[:target_type],
        target_id: event.payload[:target_id],
        target_endpoint: event.payload[:target_endpoint],
        goods_nomenclature_item_id: event.payload[:goods_nomenclature_item_id],
        goods_nomenclature_sid: event.payload[:goods_nomenclature_sid],
        details: event.payload[:details],
      }, event)
    end

    def fuzzy_results_returned(event)
      info log_entry({
        event: 'fuzzy_results_returned',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        result_count: event.payload[:result_count],
        chapter_result_count: event.payload[:chapter_result_count],
        heading_result_count: event.payload[:heading_result_count],
        commodity_result_count: event.payload[:commodity_result_count],
        other_result_count: event.payload[:other_result_count],
        details: event.payload[:details],
      }, event)
    end

    def interactive_configuration_used(event)
      info log_entry({
        event: 'interactive_configuration_used',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        skip_question: event.payload[:skip_question],
        details: event.payload[:details],
      }, event)
    end

    def note_evidence_evaluated(event)
      info log_entry({
        event: 'note_evidence_evaluated',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        effective_query: event.payload[:effective_query],
        iteration: event.payload[:iteration],
        attempt_number: event.payload[:attempt_number],
        operation: event.payload[:operation],
        note_evidence_enabled: event.payload[:note_evidence_enabled],
        note_evidence_status: event.payload[:note_evidence_status],
        considered_note_count: event.payload[:considered_note_count],
        considered_evidence_count: event.payload[:considered_evidence_count],
        considered_association_count: event.payload[:considered_association_count],
        considered_distinct_source_count: event.payload[:considered_distinct_source_count],
        selected_note_count: event.payload[:selected_note_count],
        selected_evidence_count: event.payload[:selected_evidence_count],
        selected_distinct_source_count: event.payload[:selected_distinct_source_count],
        omitted_evidence_count: event.payload[:omitted_evidence_count],
        logged_omitted_evidence_count: event.payload[:logged_omitted_evidence_count],
        omitted_evidence_truncated: event.payload[:omitted_evidence_truncated],
        details: event.payload[:details],
      }, event)
    end

    def retrieval_results_returned(event)
      info log_entry({
        event: 'retrieval_results_returned',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        effective_query: event.payload[:effective_query],
        retrieval_method: event.payload[:retrieval_method],
        stage: event.payload[:stage],
        leg: event.payload[:leg],
        iteration: event.payload[:iteration],
        result_count: event.payload[:result_count],
        details: event.payload[:details],
      }, event)
    end

    def question_returned(event)
      data = {
        event: 'question_returned',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        question_count: event.payload[:question_count],
        attempt_number: event.payload[:attempt_number],
        iteration: event.payload[:iteration],
        effective_query: event.payload[:effective_query],
      }
      data[:details] = event.payload[:details] if event.payload[:details]
      info log_entry(data, event)
    end

    def answer_returned(event)
      data = {
        event: 'answer_returned',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        answer_count: event.payload[:answer_count],
        confidence_levels: event.payload[:confidence_levels],
        attempt_number: event.payload[:attempt_number],
        iteration: event.payload[:iteration],
        effective_query: event.payload[:effective_query],
      }
      data[:details] = event.payload[:details] if event.payload[:details]
      info log_entry(data, event)
    end

    def evaluation_trace_returned(event)
      info log_entry({
        event: 'evaluation_trace_returned',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        trace_version: event.payload[:trace_version],
        query: event.payload[:query],
        effective_query: event.payload[:effective_query],
        iteration: event.payload[:iteration],
        answer_count: event.payload[:answer_count],
        retrieval_method: event.payload[:retrieval_method],
        results_type: event.payload[:results_type],
        candidate_count: event.payload[:candidate_count],
        logged_candidate_count: event.payload[:logged_candidate_count],
        candidates_truncated: event.payload[:candidates_truncated],
        final_result_type: event.payload[:final_result_type],
        ranked_answer_count: event.payload[:ranked_answer_count],
        logged_ranked_answer_count: event.payload[:logged_ranked_answer_count],
        ranked_answers_truncated: event.payload[:ranked_answers_truncated],
        question_count: event.payload[:question_count],
        logged_question_count: event.payload[:logged_question_count],
        questions_truncated: event.payload[:questions_truncated],
        confidence_levels: event.payload[:confidence_levels],
        ranking_source: event.payload[:ranking_source],
        model: event.payload[:model],
        result_limit: event.payload[:result_limit],
        error_message: event.payload[:error_message],
        error_message_truncated: event.payload[:error_message_truncated],
        details: event.payload[:details],
      }, event)
    end

    def duplicate_question_guard_checked(event)
      info log_entry({
        event: 'duplicate_question_guard_checked',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        attempt_number: event.payload[:attempt_number],
        iteration: event.payload[:iteration],
        effective_query: event.payload[:effective_query],
        allowed: event.payload[:allowed],
        duplicate: event.payload[:duplicate],
        suspicious: event.payload[:suspicious],
        signals: event.payload[:signals],
        reason: event.payload[:reason],
        reason_truncated: event.payload[:reason_truncated],
        duplicate_of_question: event.payload[:duplicate_of_question],
        duplicate_of_answer: event.payload[:duplicate_of_answer],
      }, event)
    end

    def description_intercept_checked(event)
      info log_entry(description_intercept_fields(event).merge(
                       event: 'description_intercept_checked',
                       request_id: event.payload[:request_id],
                       search_type: event.payload[:search_type],
                       query: event.payload[:query],
                     ), event)
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
        chapter_result_count: event.payload[:chapter_result_count],
        heading_result_count: event.payload[:heading_result_count],
        commodity_result_count: event.payload[:commodity_result_count],
        other_result_count: event.payload[:other_result_count],
      }
      data[:results_type] = event.payload[:results_type] if event.payload[:results_type]
      data[:max_score] = event.payload[:max_score] if event.payload[:max_score]
      add_description_intercept_fields!(data, event)
      add_error_fields!(data, event)
      info log_entry(data, event)
    end

    def retrieval_leg_completed(event)
      data = {
        event: 'retrieval_leg_completed',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        leg: event.payload[:leg],
        duration_ms: event.payload[:duration_ms],
        result_count: event.payload[:result_count],
        status: event.payload[:status],
      }
      add_error_fields!(data, event)
      info log_entry(data, event)
    end

    def query_guardrail_decided(event)
      info log_entry({
        event: 'query_guardrail_decided',
        request_id: event.payload[:request_id],
        search_type: event.payload[:search_type],
        query: event.payload[:query],
        effective_query: event.payload[:effective_query],
        iteration: event.payload[:iteration],
        variant: event.payload[:variant],
        enabled: event.payload[:enabled],
        accepted: event.payload[:accepted],
        max_score: event.payload[:max_score],
        threshold: event.payload[:threshold],
        reason: event.payload[:reason],
      }, event)
    end

    def result_selected(event)
      info log_entry({
        event: 'result_selected',
        request_id: event.payload[:request_id],
        goods_nomenclature_item_id: event.payload[:goods_nomenclature_item_id],
        goods_nomenclature_class: event.payload[:goods_nomenclature_class],
      }, event)
    end

    def search_failed(event)
      data = {
        event: 'search_failed',
        request_id: event.payload[:request_id],
        error_type: event.payload[:error_type],
        search_type: event.payload[:search_type],
      }
      add_error_fields!(data, event)
      error log_entry(data, event)
    end

  private

    def log_entry(data, event)
      entry = data.merge(
        service: 'search',
        timestamp: Time.current.iso8601,
      )
      entry[:request_source] = event.payload[:request_source] if event.payload[:request_source].present?
      client_id = event.payload[:client_id].presence || TradeTariffRequest.client_id.presence
      entry[:client_id] = client_id if client_id
      entry[:experiment] = TradeTariffRequest.experiment if TradeTariffRequest.experiment.present?
      entry.to_json
    end

    def add_description_intercept_fields!(data, event)
      description_intercept_fields(event, prefix: :description_intercept).each do |key, value|
        data[key] = value
      end
    end

    def description_intercept_fields(event, prefix: nil)
      keys = %i[matched term excluded filtering filter_prefix_count guidance_level guidance_location escalate_to_webchat]

      keys.each_with_object({}) do |key, fields|
        payload_key = prefix ? [prefix, key].join('_').to_sym : key
        fields[payload_key] = event.payload[payload_key] if event.payload.key?(payload_key)
      end
    end

    def add_error_fields!(data, event)
      return unless event.payload.key?(:error_message)

      data[:error_message] = event.payload[:error_message]
      data[:error_message_truncated] = event.payload[:error_message_truncated]
    end

    def add_ai_usage_fields!(data, event)
      AiUsage.add_log_fields!(data, event)
    end
  end
end

Search::Logger.attach_to :search unless Rails.env.test?
