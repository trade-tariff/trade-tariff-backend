module Api
  module Beta
    class FacetFilterStatisticSerializer
      include JSONAPI::Serializer

      set_type :facet_filter_statistic

      attributes :facet_filter,
                 :facet_count,
                 :display_name,
                 :question

      has_many :facet_classification_statistics, serializer: Api::Beta::FacetClassificationStatisticSerializer
    end
  end
end
