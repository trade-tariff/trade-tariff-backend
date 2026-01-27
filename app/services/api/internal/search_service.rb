module Api
  module Internal
    class SearchService
      include QueryProcessing

      attr_reader :q, :as_of

      def initialize(params = {})
        @q = process_query(params[:q])
        @as_of = parse_date(params[:as_of])
      end

      def call
        if q.blank? || ::SearchService::RogueSearchService.call(q)
          return { data: [] }
        end

        results = TradeTariffBackend.search_client.search(
          ::Search::GoodsNomenclatureQuery.new(q, as_of).query,
        )

        hits = results.dig('hits', 'hits') || []
        goods_nomenclatures = hits.map { |hit| build_result(hit) }

        GoodsNomenclatureSearchSerializer.serialize(goods_nomenclatures)
      end

      private

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
    end
  end
end
