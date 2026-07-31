module Search
  module Instrumentation
    module ClassicResultSummaries
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

      NAMED_NESTED_LEVELS = {
        chapters: :chapter_result_count,
        headings: :heading_result_count,
        commodities: :commodity_result_count,
      }.freeze

      def nested_result_count(results)
        return 0 unless results.is_a?(Hash)

        %i[goods_nomenclature_match reference_match].sum do |match_type|
          groups = results[match_type] || results[match_type.to_s]
          next 0 unless groups.respond_to?(:each_value)

          groups.each_value.sum { |hits| Array(hits).size }
        end
      end

      def nested_level_result_count(results, level)
        return 0 unless results.is_a?(Hash)

        level_key = level.to_s
        %i[goods_nomenclature_match reference_match].sum do |match_type|
          groups = results[match_type] || results[match_type.to_s]
          next 0 unless groups.respond_to?(:[])

          Array(groups[level_key] || groups[level_key.to_sym]).size
        end
      end

      def nested_level_result_counts(results)
        named = NAMED_NESTED_LEVELS.each_with_object({}) do |(level, key), memo|
          memo[key] = nested_level_result_count(results, level)
        end

        named_total = named.values.sum
        total = nested_result_count(results)
        named.merge(other_result_count: [total - named_total, 0].max)
      end

      def nested_commodity_result_count(results)
        nested_level_result_count(results, :commodities)
      end
    end
  end
end
