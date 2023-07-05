module Api
  module V2
    module BulkSearch
      class SearchResultSerializer
        include JSONAPI::Serializer

        set_type :search_result_ancestor

        attributes :short_code,
                   :goods_nomenclature_item_id,
                   :description,
                   :producline_suffix,
                   :goods_nomenclature_class,
                   :declarable,
                   :reason

        attributes :score, &:presented_score
      end
    end
  end
end
