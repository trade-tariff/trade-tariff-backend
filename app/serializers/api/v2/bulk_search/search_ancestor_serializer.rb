module Api
  module V2
    module BulkSearch
      class SearchAncestorSerializer
        include JSONAPI::Serializer

        set_type :search_result_ancestor

        attributes :short_code,
                   :goods_nomenclature_item_id,
                   :description,
                   :producline_suffix,
                   :goods_nomenclature_class,
                   :declarable,
                   :score,
                   :reason
      end
    end
  end
end
