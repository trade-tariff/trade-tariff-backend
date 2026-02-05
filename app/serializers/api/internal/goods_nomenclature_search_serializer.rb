module Api
  module Internal
    class GoodsNomenclatureSearchSerializer
      include JSONAPI::Serializer

      set_type :goods_nomenclature
      set_id :goods_nomenclature_sid

      attributes :goods_nomenclature_item_id,
                 :producline_suffix,
                 :goods_nomenclature_class,
                 :description,
                 :formatted_description,
                 :full_description,
                 :heading_description,
                 :declarable,
                 :score,
                 :confidence

      def self.serialize(collection)
        data = collection.map do |record|
          serializer_for(record).new(record).serializable_hash[:data]
        end

        { data: }
      end

      def self.serializer_for(record)
        if record.try(:goods_nomenclature_class)
          "Api::Internal::#{record.goods_nomenclature_class}SearchSerializer".constantize
        else
          self
        end
      end
    end
  end
end
