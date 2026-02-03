module Api
  module Internal
    class SearchService
      include QueryProcessing

      attr_reader :q, :as_of, :answers, :request_id

      def initialize(params = {})
        @q = process_query(params[:q])
        @as_of = parse_date(params[:as_of])
        @answers = params[:answers] || []
        @request_id = params[:request_id] || SecureRandom.uuid
      end

      def call
        if q.blank? || ::SearchService::RogueSearchService.call(q)
          return { data: [] }
        end

        exact = find_exact_match
        return GoodsNomenclatureSearchSerializer.serialize([exact]) if exact

        @expanded_query = expand_query(q)

        results = search_with_configured_labels do
          TradeTariffBackend.search_client.search(
            ::Search::GoodsNomenclatureQuery.new(@expanded_query, as_of).query,
          )
        end

        hits = results.dig('hits', 'hits') || []
        goods_nomenclatures = hits.map { |hit| build_result(hit) }

        interactive_result = run_interactive_search(goods_nomenclatures)

        build_response(goods_nomenclatures, interactive_result)
      end

      private

      def expand_query(query)
        return query unless expand_search_enabled?

        ExpandSearchQueryService.call(query).expanded_query
      end

      def expand_search_enabled?
        config = AdminConfiguration.classification.by_name('expand_search_enabled')
        config.nil? || config.enabled?
      end

      def search_with_configured_labels(&block)
        config = AdminConfiguration.classification.by_name('search_labels_enabled')
        labels_enabled = config.nil? || config.enabled?

        if labels_enabled
          SearchLabels.with_labels(&block)
        else
          SearchLabels.without_labels(&block)
        end
      end

      def find_exact_match
        gn = find_by_suggestion(q) ||
          find_by_padded_code(q) ||
          find_by_goods_nomenclature(q)

        return nil unless gn
        return nil if hidden?(gn)

        build_exact_result(gn)
      end

      def find_by_suggestion(query)
        ::SearchSuggestion
          .where(value: singular_and_plural(query))
          .eager(:goods_nomenclature)
          .first
          &.goods_nomenclature
          &.sti_cast
      end

      def find_by_padded_code(query)
        return nil unless digits_only?(query)

        padded = query.ljust(10, '0')
        return nil if padded == query

        find_by_suggestion(padded)
      end

      def find_by_goods_nomenclature(query)
        return nil unless digits_only?(query)

        goods_nomenclature_item_id = query.first(10).ljust(10, '0')
        producline_suffix = query.length > 10 ? query.last(2) : nil

        filter = { goods_nomenclature_item_id: }
        filter[:producline_suffix] = producline_suffix if producline_suffix.present?

        gn = ::GoodsNomenclature.non_hidden.where(filter).first
        return nil unless gn

        TimeMachine.at(validity_date_for(gn)) { gn.sti_cast }
      end

      def hidden?(goods_nomenclature)
        ::HiddenGoodsNomenclature.codes.include?(goods_nomenclature.goods_nomenclature_item_id)
      end

      def digits_only?(query)
        /\A\d+\z/.match?(query)
      end

      def singular_and_plural(query)
        [query, query.singularize, query.pluralize].uniq
      end

      def validity_date_for(goods_nomenclature)
        if goods_nomenclature.validity_end_date && goods_nomenclature.validity_end_date < as_of
          goods_nomenclature.validity_end_date
        elsif goods_nomenclature.validity_start_date && goods_nomenclature.validity_start_date > as_of
          goods_nomenclature.validity_start_date
        else
          as_of
        end
      end

      def build_exact_result(goods_nomenclature)
        OpenStruct.new(
          id: goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          producline_suffix: goods_nomenclature.producline_suffix,
          goods_nomenclature_class: goods_nomenclature.goods_nomenclature_class,
          description: goods_nomenclature.description,
          formatted_description: goods_nomenclature.formatted_description,
          declarable: goods_nomenclature.respond_to?(:declarable?) ? goods_nomenclature.declarable? : false,
          score: nil,
          confidence: nil,
        )
      end

      def build_result(hit)
        source = hit['_source']
        OpenStruct.new(
          id: source['goods_nomenclature_sid'],
          goods_nomenclature_item_id: source['goods_nomenclature_item_id'],
          goods_nomenclature_sid: source['goods_nomenclature_sid'],
          producline_suffix: source['producline_suffix'],
          goods_nomenclature_class: source['goods_nomenclature_class'],
          description: source['description'],
          formatted_description: source['formatted_description'],
          declarable: source['declarable'],
          score: hit['_score'],
          confidence: nil,
        )
      end

      def run_interactive_search(goods_nomenclatures)
        InteractiveSearchService.call(
          query: q,
          expanded_query: @expanded_query,
          opensearch_results: goods_nomenclatures,
          answers: answers,
          request_id: request_id,
        )
      end

      def build_response(goods_nomenclatures, interactive_result)
        results_with_confidence = apply_confidence(goods_nomenclatures, interactive_result)
        response = GoodsNomenclatureSearchSerializer.serialize(results_with_confidence)
        meta = build_meta(interactive_result)
        response[:meta] = meta if meta.present?
        response
      end

      def apply_confidence(goods_nomenclatures, interactive_result)
        return goods_nomenclatures unless interactive_result&.type == :answers

        confidence_map = interactive_result.data.each_with_object({}) do |answer, hash|
          hash[answer[:commodity_code]] = answer[:confidence]
        end

        goods_nomenclatures.map do |gn|
          gn.confidence = confidence_map[gn.goods_nomenclature_item_id]
          gn
        end
      end

      def build_meta(interactive_result)
        meta = {}

        if interactive_result
          interactive_meta = {
            query: q,
            request_id: request_id,
            attempt: interactive_result.attempt,
            model: interactive_result.model,
            result_limit: interactive_result.result_limit,
            answers: build_answers_list(interactive_result),
          }

          if @expanded_query.present? && @expanded_query != q
            interactive_meta[:expanded_query] = @expanded_query
          end

          if interactive_result.type == :error
            interactive_meta[:error] = interactive_result.data[:message]
          end

          meta[:interactive_search] = interactive_meta
        end

        meta.presence
      end

      def build_answers_list(interactive_result)
        # Start with previously answered questions (preserve options if frontend sent them)
        answered = answers.map do |qa|
          {
            question: qa[:question] || qa['question'],
            options: qa[:options] || qa['options'],
            answer: qa[:answer] || qa['answer'],
          }
        end

        # Add current unanswered question if present
        if interactive_result.type == :questions
          question_data = interactive_result.data.first
          answered << {
            question: question_data[:question],
            options: question_data[:options],
            answer: nil,
          }
        end

        answered
      end
    end
  end
end
