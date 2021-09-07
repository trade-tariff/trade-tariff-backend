class TaricImporter
  class RecordProcessor
    class GoodsNomenclatureDestroyOperation < DestroyOperation
      def call
        goods_nomenclature = record.klass.filter(attributes.slice(*record.primary_key).symbolize_keys).take
        goods_nomenclature.set(attributes.except(*record.primary_key).symbolize_keys)
        goods_nomenclature.destroy

        ::Measure.where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
               .national
               .non_invalidated.each do |measure|
          if measure.goods_nomenclature.blank?
            measure.invalidated_by = record.transaction_id
            measure.invalidated_at = Time.now
            measure.save
          end
        end

        goods_nomenclature
      end
    end
  end
end
