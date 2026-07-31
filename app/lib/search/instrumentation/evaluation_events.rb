module Search
  module Instrumentation
    module EvaluationEvents
      def evaluation_trace_returned(request_id:, query:, effective_query:, iteration:, answer_count:, retrieval_method:, results_type:, candidates:, final_result_type:, ranked_answers:, questions:, error_message:, ranking_source:, model:, result_limit:)
        candidate_summaries = summarize_results(candidates)
        ranked_answer_summaries = summarize_ranked_answers(ranked_answers)
        question_summaries = summarize_questions(questions)

        instrument(
          'evaluation_trace_returned',
          request_id:,
          search_type: 'interactive',
          trace_version: EVALUATION_TRACE_VERSION,
          query:,
          effective_query:,
          iteration:,
          answer_count:,
          retrieval_method:,
          results_type:,
          candidate_count: Array(candidates).size,
          logged_candidate_count: candidate_summaries.size,
          candidates_truncated: candidate_summaries.size < Array(candidates).size,
          final_result_type:,
          ranked_answer_count: Array(ranked_answers).size,
          logged_ranked_answer_count: ranked_answer_summaries.size,
          ranked_answers_truncated: ranked_answer_summaries.size < Array(ranked_answers).size,
          question_count: Array(questions).size,
          logged_question_count: question_summaries.size,
          questions_truncated: question_summaries.size < Array(questions).size,
          confidence_levels: confidence_levels_for(ranked_answer_summaries),
          ranking_source:,
          model:,
          result_limit:,
          details: {
            candidates: candidate_summaries,
            ranked_answers: ranked_answer_summaries,
            questions: question_summaries,
          }.compact_blank,
          **truncate_error_payload(error_message),
        )
      end

      def search_completed(request_id:, search_type:, total_duration_ms:, result_count:, query: nil, total_attempts: nil, total_questions: nil, final_result_type: nil, results_type: nil, max_score: nil, error_message: nil, description_intercept: nil, commodity_result_count: nil, chapter_result_count: nil, heading_result_count: nil, other_result_count: nil)
        payload = {
          request_id:,
          query:,
          search_type:,
          total_attempts:,
          total_questions:,
          final_result_type:,
          total_duration_ms:,
          result_count:,
          # Classic fuzzy supplies an explicit per-level breakdown. Interactive/internal
          # completions treat result_count as commodity-equivalent and leave other levels at 0.
          chapter_result_count: chapter_result_count || 0,
          heading_result_count: heading_result_count || 0,
          commodity_result_count: commodity_result_count.nil? ? result_count : commodity_result_count,
          other_result_count: other_result_count || 0,
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
    end
  end
end
