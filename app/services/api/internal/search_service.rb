module Api
  module Internal
    class SearchService
      include QueryProcessing

      attr_reader :q, :as_of, :answers, :request_id

      def initialize(params = {})
        sanitiser_result = InputSanitiser.new(params[:q]).call

        if sanitiser_result[:errors]
          @sanitiser_errors = sanitiser_result
          @q = ''
        else
          @q = process_query(sanitiser_result[:query])
        end

        @as_of = parse_date(params[:as_of])
        @answers = normalize_answers(params[:answers])
        @request_id = params[:request_id] || SecureRandom.uuid
      end

      def call
        return @sanitiser_errors if @sanitiser_errors

        if q.blank? || ::SearchService::RogueSearchService.call(q)
          return { data: [] }
        end

        ::Search::Instrumentation.search(request_id:, query: q, search_type: 'interactive') do
          exact = find_exact_match
          if exact
            next [GoodsNomenclatureSearchSerializer.serialize([exact]),
                  { result_count: 1, results_type: 'exact_match' }]
          end

          if vector_retrieval?
            goods_nomenclatures = VectorRetrievalService.call(
              query: q,
              as_of: as_of,
              limit: opensearch_result_limit,
            )

            interactive_result = run_interactive_search(goods_nomenclatures)
            max_score = goods_nomenclatures.map(&:score).compact.max
          else
            @expanded_query = expand_query(q)

            results = search_with_configured_labels do
              TradeTariffBackend.search_client.search(
                ::Search::GoodsNomenclatureQuery.new(
                  q,
                  as_of,
                  expanded_query: @expanded_query,
                  pos_search: pos_search_enabled?,
                  size: opensearch_result_limit,
                  noun_boost: pos_noun_boost,
                  qualifier_boost: pos_qualifier_boost,
                ).query,
              )
            end

            hits = results.dig('hits', 'hits') || []
            goods_nomenclatures = hits.map { |hit| build_result_from_hit(hit) }

            interactive_result = run_interactive_search(goods_nomenclatures)
            max_score = hits.map { |hit| hit['_score'] }.compact.max
          end

          response = build_response(goods_nomenclatures, interactive_result)
          completion = {
            result_count: response[:data]&.size || 0,
            total_attempts: interactive_result&.attempt,
            total_questions: answers.size,
            final_result_type: interactive_result&.type&.to_s,
            results_type: vector_retrieval? ? 'vector' : 'opensearch',
            max_score: max_score,
          }

          [response, completion]
        end
      end

      private

      def vector_retrieval?
        AdminConfiguration.option_value('retrieval_method') == 'vector'
      end

      def expand_query(query)
        return query unless expand_search_enabled?

        result = ::Search::Instrumentation.query_expanded(
          request_id:,
          original_query: query,
        ) { ExpandSearchQueryService.call(query) }

        result.expanded_query
      end

      def expand_search_enabled?
        AdminConfiguration.enabled?('expand_search_enabled')
      end

      def pos_search_enabled?
        AdminConfiguration.enabled?('pos_search_enabled')
      end

      def opensearch_result_limit
        AdminConfiguration.integer_value('opensearch_result_limit')
      end

      def pos_noun_boost
        AdminConfiguration.integer_value('pos_noun_boost')
      end

      def pos_qualifier_boost
        AdminConfiguration.integer_value('pos_qualifier_boost')
      end

      def search_with_configured_labels(&block)
        if AdminConfiguration.enabled?('search_labels_enabled')
          SearchLabels.with_labels(&block)
        else
          SearchLabels.without_labels(&block)
        end
      end

      def allowed_suggestion_types
        ::SearchSuggestion.allowed_types
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
          .where(type: allowed_suggestion_types)
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
          full_description: SelfTextLookupService.lookup(goods_nomenclature.goods_nomenclature_item_id).presence || goods_nomenclature.classification_description,
          heading_description: goods_nomenclature.heading&.formatted_description,
          declarable: goods_nomenclature.respond_to?(:declarable?) ? goods_nomenclature.declarable? : false,
          score: nil,
          confidence: nil,
        )
      end

      def build_result_from_hit(hit)
        source = hit['_source']
        OpenStruct.new(
          id: source['goods_nomenclature_sid'],
          goods_nomenclature_item_id: source['goods_nomenclature_item_id'],
          goods_nomenclature_sid: source['goods_nomenclature_sid'],
          producline_suffix: source['producline_suffix'],
          goods_nomenclature_class: source['goods_nomenclature_class'],
          description: source['description'],
          formatted_description: source['formatted_description'],
          full_description: source['full_description'],
          heading_description: source['heading_description'],
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
        results = build_results_with_confidence(goods_nomenclatures, interactive_result)
        response = GoodsNomenclatureSearchSerializer.serialize(results)
        meta = build_meta(interactive_result)
        response[:meta] = meta if meta.present?
        response
      end

      def build_results_with_confidence(goods_nomenclatures, interactive_result)
        return goods_nomenclatures unless interactive_result&.type == :answers

        results_by_code = goods_nomenclatures.index_by(&:goods_nomenclature_item_id)

        interactive_result.data.filter_map do |answer|
          result = results_by_code[answer[:commodity_code]]
          next unless result

          build_result(result, answer[:confidence])
        end
      end

      def build_result(result, confidence)
        OpenStruct.new(
          id: result.id,
          goods_nomenclature_item_id: result.goods_nomenclature_item_id,
          goods_nomenclature_sid: result.goods_nomenclature_sid,
          producline_suffix: result.producline_suffix,
          goods_nomenclature_class: result.goods_nomenclature_class,
          description: result.description,
          formatted_description: result.formatted_description,
          full_description: result.full_description,
          heading_description: result.heading_description,
          declarable: result.declarable,
          score: result.score,
          confidence: confidence,
        )
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

      def normalize_answers(answers_param)
        return [] if answers_param.blank?

        answers_param.map do |qa|
          qa = qa.to_h.symbolize_keys
          {
            question: qa[:question],
            options: normalize_options(qa[:options]),
            answer: qa[:answer],
          }
        end
      end

      def normalize_options(options)
        return options if options.is_a?(Array)
        return [] if options.blank?

        parsed = JSON.parse(options)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        []
      end

      def build_answers_list(interactive_result)
        answered = answers.map do |qa|
          { question: qa[:question], options: qa[:options], answer: qa[:answer] }
        end

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
