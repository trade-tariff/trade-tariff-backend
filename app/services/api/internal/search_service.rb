module Api
  module Internal
    class SearchService
      include QueryProcessing

      RetrievalResult = Struct.new(:goods_nomenclatures, :max_score, :expanded_query, :results_type, keyword_init: true)

      attr_reader :q, :as_of, :answers, :request_id, :description_intercept

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

        return { data: [] } if q.blank?

        @description_intercept = DescriptionIntercept.for_search(q, source: 'guided_search')
        ::Search::Instrumentation.description_intercept_checked(
          request_id:,
          query: q,
          description_intercept:,
        )
        return empty_response if description_intercept&.excluded

        ::Search::Instrumentation.search(request_id:, query: q, search_type: 'interactive') do
          exact = find_exact_match
          if exact
            next [with_description_intercept_meta(GoodsNomenclatureSearchSerializer.serialize([exact])),
                  completion_payload(result_count: 1, results_type: 'exact_match')]
          end

          retrieval = retrieve_short_list

          if retrieval.goods_nomenclatures.empty?
            next [empty_response, completion_payload(result_count: 0, results_type: retrieval.results_type)]
          end

          interactive_result = run_interactive_search(
            retrieval.goods_nomenclatures,
            retrieval.expanded_query,
          )

          response = build_response(
            retrieval.goods_nomenclatures,
            interactive_result,
            retrieval.expanded_query,
          )
          completion = completion_payload(
            result_count: response[:data]&.size || 0,
            total_attempts: interactive_result&.attempt,
            total_questions: answers.size,
            final_result_type: interactive_result&.type&.to_s,
            results_type: retrieval.results_type,
            max_score: retrieval.max_score,
            error_message: interactive_result&.type == :error ? interactive_result.data[:message] : nil,
          )

          [response, completion]
        end
      end

      private

      def completion_payload(**payload)
        return payload unless description_intercept

        payload.merge(description_intercept:)
      end

      def retrieve_short_list
        case retrieval_method
        when 'vector' then vector_short_list
        when 'hybrid' then hybrid_short_list
        else opensearch_short_list
        end
      end

      def retrieval_method
        AdminConfiguration.option_value('retrieval_method')
      end

      def vector_short_list
        goods_nomenclatures = VectorRetrievalService.call(
          query: q,
          limit: opensearch_result_limit,
          filter_prefixes: filter_prefixes,
        )

        RetrievalResult.new(
          goods_nomenclatures: goods_nomenclatures,
          max_score: goods_nomenclatures.map(&:score).compact.max,
          results_type: 'vector',
        )
      end

      def opensearch_short_list
        result = OpensearchRetrievalService.call(
          query: q, as_of: as_of, request_id: request_id, limit: opensearch_result_limit,
          filter_prefixes: filter_prefixes
        )

        RetrievalResult.new(
          goods_nomenclatures: result.results,
          max_score: result.results.map(&:score).compact.max,
          expanded_query: result.expanded_query,
          results_type: 'opensearch',
        )
      end

      def hybrid_short_list
        result = HybridRetrievalService.call(
          query: q, as_of: as_of, request_id: request_id, limit: opensearch_result_limit,
          filter_prefixes: filter_prefixes
        )

        RetrievalResult.new(
          goods_nomenclatures: result.results,
          max_score: result.results.map(&:score).compact.max,
          expanded_query: result.expanded_query,
          results_type: 'hybrid',
        )
      end

      def opensearch_result_limit
        AdminConfiguration.integer_value('opensearch_result_limit')
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
        return nil unless allowed_by_description_intercept_filter?(gn)

        build_exact_result(gn)
      end

      def find_by_suggestion(query)
        ::SearchSuggestion
          .declarable
          .by_value(singular_and_plural(query))
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
        ::HiddenGoodsNomenclature.codes.include?(goods_nomenclature.goods_nomenclature_item_id) ||
          excluded_chapter?(goods_nomenclature)
      end

      def excluded_chapter?(goods_nomenclature)
        AdminConfiguration.multi_options_values('interactive_search_excluded_chapters')
          .include?(goods_nomenclature.chapter_short_code.to_s)
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
        self_text = goods_nomenclature.goods_nomenclature_self_text&.self_text

        GoodsNomenclatureResult.new(
          id: goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          producline_suffix: goods_nomenclature.producline_suffix,
          goods_nomenclature_class: goods_nomenclature.goods_nomenclature_class,
          description: goods_nomenclature.description,
          formatted_description: goods_nomenclature.formatted_description,
          self_text: self_text,
          classification_description: goods_nomenclature.classification_description,
          full_description: self_text.presence || goods_nomenclature.classification_description,
          heading_description: goods_nomenclature.heading&.formatted_description,
          declarable: goods_nomenclature.respond_to?(:declarable?) ? goods_nomenclature.declarable? : false,
          score: nil,
          confidence: nil,
        )
      end

      def run_interactive_search(goods_nomenclatures, expanded_query)
        InteractiveSearchService.call(
          query: q,
          expanded_query: expanded_query,
          opensearch_results: goods_nomenclatures,
          answers: answers,
          request_id: request_id,
        )
      end

      def build_response(goods_nomenclatures, interactive_result, expanded_query)
        results = build_results_with_confidence(goods_nomenclatures, interactive_result)
        response = GoodsNomenclatureSearchSerializer.serialize(results)
        meta = build_meta(interactive_result, expanded_query)
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
        GoodsNomenclatureResult.new(
          id: result.id,
          goods_nomenclature_item_id: result.goods_nomenclature_item_id,
          goods_nomenclature_sid: result.goods_nomenclature_sid,
          producline_suffix: result.producline_suffix,
          goods_nomenclature_class: result.goods_nomenclature_class,
          description: result.description,
          formatted_description: result.formatted_description,
          self_text: result.self_text,
          classification_description: result.classification_description,
          full_description: result.full_description,
          heading_description: result.heading_description,
          declarable: result.declarable,
          score: result.score,
          confidence: confidence,
        )
      end

      def build_meta(interactive_result, expanded_query)
        meta = {}
        meta[:description_intercept] = description_intercept.search_metadata if description_intercept

        if interactive_result
          interactive_meta = {
            query: q,
            request_id: request_id,
            attempt: interactive_result.attempt,
            model: interactive_result.model,
            result_limit: interactive_result.result_limit,
            answers: build_answers_list(interactive_result),
          }

          if expanded_query.present? && expanded_query != q
            interactive_meta[:expanded_query] = expanded_query
          end

          if interactive_result.type == :error
            interactive_meta[:error] = interactive_result.data[:message]
          end

          meta[:interactive_search] = interactive_meta
        end

        meta.presence
      end

      def empty_response
        with_description_intercept_meta({ data: [] })
      end

      def with_description_intercept_meta(response)
        return response unless description_intercept

        response.merge(meta: (response[:meta] || {}).merge(description_intercept: description_intercept.search_metadata))
      end

      def filter_prefixes
        description_intercept&.filter_prefixes_array || []
      end

      def allowed_by_description_intercept_filter?(goods_nomenclature)
        return true if filter_prefixes.empty?

        filter_prefixes.any? { |prefix| goods_nomenclature.goods_nomenclature_item_id.to_s.start_with?(prefix) }
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
