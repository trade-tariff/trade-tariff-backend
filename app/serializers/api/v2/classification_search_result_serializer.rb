module Api
  module V2
    class ClassificationSearchResultSerializer
      include JSONAPI::Serializer

      set_type :classification_search_result
      set_id :goods_nomenclature_sid

      attributes :goods_nomenclature_item_id,
                 :goods_nomenclature_sid,
                 :producline_suffix,
                 :goods_nomenclature_class,
                 :description,
                 :formatted_description,
                 :self_text,
                 :classification_description,
                 :full_description,
                 :heading_description,
                 :declarable,
                 :score,
                 :confidence

      def self.serialize(collection, meta:)
        {
          data: collection.map { |record| new(record).serializable_hash[:data] },
          meta:,
        }
      end
    end
  end
end
