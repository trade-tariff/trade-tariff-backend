module Api
  module Beta
    class SearchResultSerializer
      include JSONAPI::Serializer

      set_type :search_result

      attributes :took,
                 :timed_out,
                 :max_score,
                 :total_results

      has_one :search_query_parser_result, serializer: SearchQueryParserResultSerializer

      has_many :hits, serializer: proc { |record, _params|
        if record && record.respond_to?(:goods_nomenclature_class)
          "Api::Beta::#{record.goods_nomenclature_class}Serializer".constantize
        else
          Api::Beta::GoodsNomenclatureSerializer
        end
      }

      has_many :heading_statistics, serializer: HeadingStatisticsSerializer
      has_many :chapter_statistics, serializer: ChapterStatisticsSerializer
    end
  end
end
