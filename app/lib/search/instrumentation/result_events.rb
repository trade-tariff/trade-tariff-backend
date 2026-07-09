module Search
  module Instrumentation
    module ResultEvents
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

      def interactive_configuration_used(request_id:, query:, skip_question:, configuration:)
        instrument(
          'interactive_configuration_used',
          request_id:,
          search_type: 'interactive',
          query:,
          skip_question:,
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
    end
  end
end
