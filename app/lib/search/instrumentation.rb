require 'active_support/notifications'

module Search
  module Instrumentation
  module_function

    extend QueryEvents
    extend ApiEvents
    extend ResultEvents
    extend EvaluationEvents

    ERROR_MESSAGE_MAX_LENGTH = 500
    MAX_LOGGED_RESULTS = 50
    EVALUATION_TRACE_VERSION = 'classification_evaluation_trace.v1'.freeze

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.search", with_request_context(payload), &block)
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

    def truncate_error_payload(error_message)
      return {} if error_message.blank?

      message = error_message.to_s

      {
        error_message: message.first(ERROR_MESSAGE_MAX_LENGTH),
        error_message_truncated: message.length > ERROR_MESSAGE_MAX_LENGTH,
      }
    end

    def truncate_reason_payload(reason)
      return { reason: nil, reason_truncated: false } if reason.blank?

      message = reason.to_s
      {
        reason: message.first(ERROR_MESSAGE_MAX_LENGTH),
        reason_truncated: message.length > ERROR_MESSAGE_MAX_LENGTH,
      }
    end

    def with_request_context(payload)
      return payload unless payload.key?(:request_id)

      payload
        .merge(request_id: payload[:request_id].presence || TradeTariffRequest.request_id.presence || SecureRandom.uuid)
        .merge(request_source_payload)
    end

    def request_source_payload
      return {} if TradeTariffRequest.request_source.blank?

      { request_source: TradeTariffRequest.request_source }
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

    def summarize_ranked_answers(answers)
      Array(answers).first(MAX_LOGGED_RESULTS).filter_map do |answer|
        next unless answer.respond_to?(:[])

        summary = {
          commodity_code: answer[:commodity_code] || answer['commodity_code'],
          confidence: answer[:confidence] || answer['confidence'],
        }.compact_blank
        summary.presence
      end
    end

    def summarize_questions(questions)
      Array(questions).first(MAX_LOGGED_RESULTS).filter_map do |question|
        next unless question.respond_to?(:[])

        summary = {
          question: question[:question] || question['question'],
          options: question[:options] || question['options'],
        }.compact_blank
        summary.presence
      end
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

    def confidence_levels_for(answers)
      answers.filter_map { |answer| answer[:confidence] || answer['confidence'] }.tally
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
