module Search
  module Instrumentation
    module ResultSummaries
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
    end
  end
end
