require 'active_support/notifications'

module Search
  module Instrumentation
    module_function

    ERROR_MESSAGE_MAX_LENGTH = 500
    MAX_LOGGED_RESULTS = 50

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.search", with_request_id(payload), &block)
    end

    def search_started(request_id:, query:, search_type:)
      instrument('search_started', request_id:, query:, search_type:)
    end

    def search(request_id:, query:, search_type:)
      search_started(request_id:, query:, search_type:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result, completion_payload = yield

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      search_completed(request_id:, query:, search_type:, total_duration_ms: duration_ms, **(completion_payload || {}))

      result
    rescue StandardError => e
      search_failed(request_id:, error_type: e.class.name, error_message: e.message, search_type:)
      raise
    end

    def query_expanded(request_id:, original_query:)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        'query_expanded',
        request_id:,
        search_type: 'interactive',
        original_query:,
        expanded_query: result.expanded_query,
        reason: result.reason,
        duration_ms: (duration * 1000).round(2),
      )

      result
    end

    def query_refined(request_id:, original_query:, refined_query:, answer_count:, base_query: original_query, effective_query: refined_query, added_answers: [], iteration: nil)
      result = yield
      instrument(
        'query_refined',
        request_id:,
        search_type: 'interactive',
        base_query:,
        original_query:,
        refined_query:,
        effective_query:,
        answer_count:,
        added_answers:,
        iteration:,
      )
      result
    end

    def query_expansion_decided(request_id:, query:, expand:, reason:, result_count:, max_score:)
      instrument('query_expansion_decided', request_id:, search_type: 'interactive', query:, expand:, reason:, result_count:, max_score:)
    end

    def api_call(request_id:, model:, attempt_number:, iteration: nil, effective_query: nil)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      instrument(
        'api_call_completed',
        {
          request_id:,
          search_type: 'interactive',
          model:,
          duration_ms: (duration * 1000).round(2),
          response_type: determine_response_type(result),
          attempt_number:,
          iteration:,
          effective_query:,
        }.merge(error_payload_for_result(result)),
      )

      result
    rescue StandardError => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      instrument(
        'api_call_completed',
        {
          request_id:,
          search_type: 'interactive',
          model:,
          duration_ms: (duration * 1000).round(2),
          response_type: 'error',
          attempt_number:,
          iteration:,
          effective_query:,
        }.merge(truncate_error_payload(e.message)),
      )
      search_failed(request_id:, error_type: e.class.name, error_message: e.message, search_type: 'interactive')
      raise
    end

    def exact_match_selected(request_id:, search_type:, query:, match_source:, matched_value:, result:)
      result_fields = result_summary(result)
      instrument(
        'exact_match_selected',
        {
          request_id:,
          search_type:,
          query:,
          match_source:,
          matched_value:,
          target_type: result_fields[:goods_nomenclature_class],
          target_id: result_fields[:target_id],
          target_endpoint: result_fields[:target_endpoint],
          goods_nomenclature_item_id: result_fields[:goods_nomenclature_item_id],
          goods_nomenclature_sid: result_fields[:goods_nomenclature_sid],
          details: result_fields,
        },
      )
    end

    def fuzzy_results_returned(request_id:, query:, results:)
      instrument(
        'fuzzy_results_returned',
        request_id:,
        search_type: 'classic',
        query:,
        result_count: nested_result_count(results),
        details: summarize_classic_fuzzy_results(results),
      )
    end

    def interactive_configuration_used(request_id:, query:, configuration:)
      instrument(
        'interactive_configuration_used',
        request_id:,
        search_type: 'interactive',
        query:,
        details: configuration,
      )
    end

    def retrieval_results_returned(request_id:, query:, search_type:, retrieval_method:, stage:, results:, effective_query: nil, leg: nil, iteration: nil)
      instrument(
        'retrieval_results_returned',
        request_id:,
        search_type:,
        query:,
        effective_query:,
        retrieval_method:,
        stage:,
        leg:,
        iteration:,
        result_count: Array(results).size,
        details: { results: summarize_results(results) },
      )
    end

    def question_returned(request_id:, question_count:, attempt_number:, iteration: nil, effective_query: nil, questions: nil)
      payload = { request_id:, search_type: 'interactive', question_count:, attempt_number:, iteration:, effective_query: }
      payload[:details] = { questions: questions } if questions
      instrument('question_returned', payload)
    end

    def answer_returned(request_id:, answer_count:, confidence_levels:, attempt_number:, iteration: nil, effective_query: nil, answers: nil)
      payload = { request_id:, search_type: 'interactive', answer_count:, confidence_levels:, attempt_number:, iteration:, effective_query: }
      payload[:details] = { answers: answers } if answers
      instrument('answer_returned', payload)
    end

    def search_completed(request_id:, search_type:, total_duration_ms:, result_count:, query: nil, total_attempts: nil, total_questions: nil, final_result_type: nil, results_type: nil, max_score: nil, error_message: nil, description_intercept: nil)
      payload = {
        request_id:,
        query:,
        search_type:,
        total_attempts:,
        total_questions:,
        final_result_type:,
        total_duration_ms:,
        result_count:,
      }
      payload[:results_type] = results_type if results_type
      payload[:max_score] = max_score if max_score
      payload.merge!(description_intercept_payload(description_intercept, prefix: :description_intercept))
      payload.merge!(truncate_error_payload(error_message))
      instrument('search_completed', payload)
    end

    def description_intercept_checked(request_id:, query:, description_intercept:)
      instrument(
        'description_intercept_checked',
        { request_id:, search_type: 'interactive', query: }.merge(description_intercept_payload(description_intercept)),
      )
    end

    def retrieval_leg_completed(request_id:, leg:, duration_ms:, result_count:, status:, error_message: nil)
      instrument(
        'retrieval_leg_completed',
        {
          request_id:,
          search_type: 'interactive',
          leg:,
          duration_ms:,
          result_count:,
          status:,
        }.merge(truncate_error_payload(error_message)),
      )
    end

    def result_selected(request_id:, goods_nomenclature_item_id:, goods_nomenclature_class:)
      instrument('result_selected', request_id:, goods_nomenclature_item_id:, goods_nomenclature_class:)
    end

    def search_failed(request_id:, error_type:, error_message:, search_type:)
      instrument(
        'search_failed',
        {
          request_id:,
          error_type:,
          search_type:,
        }.merge(truncate_error_payload(error_message)),
      )
    end

    def description_intercept_payload(description_intercept, prefix: nil)
      payload = if description_intercept
                  {
                    matched: true,
                    term: description_intercept.term,
                    excluded: description_intercept.excluded,
                    filtering: description_intercept.filtering?,
                    filter_prefix_count: description_intercept.filter_prefixes_array.size,
                    guidance_level: description_intercept.guidance_level,
                    guidance_location: description_intercept.guidance_location,
                    escalate_to_webchat: description_intercept.escalate_to_webchat,
                  }
                else
                  { matched: false }
                end

      return payload unless prefix

      payload.transform_keys { |key| [prefix, key].join('_').to_sym }
    end

    def determine_response_type(result)
      return 'unknown' if result.nil?

      parsed = parse_result(result)
      return 'error' if parsed.is_a?(Hash) && parsed['error'].present?
      return 'answers' if parsed.is_a?(Hash) && parsed['answers'].present?
      return 'questions' if parsed.is_a?(Hash) && parsed['questions'].is_a?(Array) && parsed['questions'].any?

      'unknown'
    rescue StandardError
      'unknown'
    end

    def error_payload_for_result(result)
      parsed = parse_result(result)
      return {} unless parsed.is_a?(Hash) && parsed['error'].present?

      truncate_error_payload(parsed['error'])
    rescue StandardError
      {}
    end

    def parse_result(result)
      result.is_a?(String) ? ExtractBottomJson.call(result) : result
    end

    def truncate_error_payload(error_message)
      return {} if error_message.blank?

      message = error_message.to_s

      {
        error_message: message.first(ERROR_MESSAGE_MAX_LENGTH),
        error_message_truncated: message.length > ERROR_MESSAGE_MAX_LENGTH,
      }
    end

    def with_request_id(payload)
      return payload unless payload.key?(:request_id)

      payload.merge(request_id: payload[:request_id].presence || TradeTariffRequest.request_id.presence || SecureRandom.uuid)
    end

    def summarize_classic_fuzzy_results(results)
      return {} unless results.is_a?(Hash)

      %i[goods_nomenclature_match reference_match].each_with_object({}) do |match_type, memo|
        groups = results[match_type] || results[match_type.to_s]
        next unless groups.respond_to?(:each_pair)

        memo[match_type] = groups.each_with_object({}) do |(level, hits), level_memo|
          level_memo[level] = summarize_hits(hits, level:)
        end
      end
    end

    def summarize_hits(hits, level:)
      Array(hits).first(MAX_LOGGED_RESULTS).map do |hit|
        source = hit['_source'] || hit[:_source] || {}
        reference = source['reference'] || source[:reference] || {}
        target = reference.presence || source
        goods_nomenclature_class = target['class'] || target[:class] ||
          source['reference_class'] || source[:reference_class] ||
          target['goods_nomenclature_class'] || target[:goods_nomenclature_class] ||
          level.to_s.singularize.camelize
        goods_nomenclature_item_id = target['goods_nomenclature_item_id'] || target[:goods_nomenclature_item_id]
        goods_nomenclature_sid = target['goods_nomenclature_sid'] || target[:goods_nomenclature_sid] || target['id'] || target[:id]
        producline_suffix = target['producline_suffix'] || target[:producline_suffix]
        {
          target_endpoint: level.to_s,
          target_id: target_id_for_classic_hit(level, goods_nomenclature_item_id, producline_suffix),
          goods_nomenclature_item_id: goods_nomenclature_item_id,
          goods_nomenclature_sid: goods_nomenclature_sid,
          goods_nomenclature_class: goods_nomenclature_class,
          producline_suffix: producline_suffix,
          reference_id: reference['id'] || reference[:id],
          reference_title: reference['title'] || reference[:title],
          score: hit['_score'] || hit[:_score],
        }.compact_blank
      end
    end

    def summarize_results(results)
      Array(results).first(MAX_LOGGED_RESULTS).map { |result| result_summary(result) }
    end

    def result_summary(result)
      {
        target_endpoint: result_endpoint(result),
        target_id: target_id_for_result(result),
        goods_nomenclature_item_id: result.try(:goods_nomenclature_item_id),
        goods_nomenclature_sid: result.try(:goods_nomenclature_sid) || result.try(:id),
        goods_nomenclature_class: result.try(:goods_nomenclature_class),
        producline_suffix: result.try(:producline_suffix),
        score: result.try(:score),
        confidence: result.try(:confidence),
        has_self_text: result.respond_to?(:self_text) ? result.self_text.present? : nil,
        self_text_id: result.try(:goods_nomenclature_sid) || result.try(:id),
        label_id: result.try(:goods_nomenclature_sid) || result.try(:id),
      }.compact_blank
    end

    def result_endpoint(result)
      result.try(:goods_nomenclature_class).to_s.underscore.pluralize.presence ||
        result.class.name.demodulize.underscore.pluralize
    end

    def target_id_for_result(result)
      return result.to_param if result.is_a?(GoodsNomenclature)

      result.try(:goods_nomenclature_item_id)
    end

    def target_id_for_classic_hit(level, goods_nomenclature_item_id, producline_suffix)
      return if goods_nomenclature_item_id.blank?

      case level.to_s
      when 'chapters'
        goods_nomenclature_item_id.first(2)
      when 'headings'
        goods_nomenclature_item_id.first(4)
      when 'subheadings'
        [goods_nomenclature_item_id, producline_suffix].compact_blank.join('-')
      else
        goods_nomenclature_item_id
      end
    end

    def nested_result_count(results)
      return 0 unless results.is_a?(Hash)

      %i[goods_nomenclature_match reference_match].sum do |match_type|
        groups = results[match_type] || results[match_type.to_s]
        next 0 unless groups.respond_to?(:each_value)

        groups.each_value.sum { |hits| Array(hits).size }
      end
    end
  end
end
