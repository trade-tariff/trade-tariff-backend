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
        config.nil? || config.value == true
      end

      def search_with_configured_labels(&block)
        config = AdminConfiguration.classification.by_name('search_labels_enabled')
        labels_enabled = config.nil? || config.value == true

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
        response = GoodsNomenclatureSearchSerializer.serialize(goods_nomenclatures)
        meta = build_meta(interactive_result)
        response[:meta] = meta if meta.present?
        response
      end

      def build_meta(interactive_result)
        meta = {}

        if @expanded_query.present? && @expanded_query != q
          meta[:expanded_query] = @expanded_query
        end

        if interactive_result
          meta[:interactive_search] = {
            type: interactive_result.type,
            data: interactive_result.data,
            request_id: request_id,
            attempt: interactive_result.attempt,
            model: interactive_result.model,
          }
        end

        meta.presence
      end
    end
  end
end
