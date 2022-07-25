module Api
  module Beta
    class FacetClassificationStatisticSerializer
      include JSONAPI::Serializer

      set_type :facet_classification_statistic

      attributes :facet,
                 :classification,
                 :count
    end
  end
end
