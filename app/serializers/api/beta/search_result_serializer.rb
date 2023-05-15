module Api
  module Beta
    class SearchResultSerializer
      include JSONAPI::Serializer

      set_type :search_result

      attributes :took,
                 :timed_out,
                 :max_score,
                 :total_results

      has_one :search_query_parser_result, serializer: Api::Beta::SearchQueryParserResultSerializer
      has_one :intercept_message, serializer: Api::Beta::InterceptMessageSerializer

      if TradeTariffBackend.beta_search_debug?
        has_one :goods_nomenclature_query, serializer: Api::Beta::GoodsNomenclatureQuerySerializer
      end

      has_many :hits, serializer: Api::Beta::GoodsNomenclatureSerializer.serializer_proc
      has_one  :direct_hit, serializer: Api::Beta::GoodsNomenclatureSerializer.serializer_proc
      has_many :heading_statistics, serializer: Api::Beta::HeadingStatisticsSerializer
      has_many :chapter_statistics, serializer: Api::Beta::ChapterStatisticsSerializer
      has_one  :guide, serializer: Api::Beta::GuideSerializer
      has_many :facet_filter_statistics, serializer: Api::Beta::FacetFilterStatisticSerializer
    end
  end
end
