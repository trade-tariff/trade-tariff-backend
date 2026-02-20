module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureSelfTextSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature_self_text
        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :self_text,
                   :generation_type,
                   :needs_review,
                   :manually_edited,
                   :stale,
                   :generated_at,
                   :eu_self_text,
                   :similarity_score,
                   :coherence_score

        attribute :input_context do |record|
          context = record.input_context || {}
          ancestors = context['ancestors']
          next context if ancestors.blank?

          sids = ancestors.map { |a| a['sid'] }.compact
          texts = GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: sids)
            .select_map(%i[goods_nomenclature_sid self_text])
            .to_h

          enriched = ancestors.map do |ancestor|
            st = texts[ancestor['sid']]
            st ? ancestor.merge('self_text' => st) : ancestor
          end

          context.merge('ancestors' => enriched)
        end

        attribute :nomenclature_type do |record|
          record.values.key?(:nomenclature_type) ? record[:nomenclature_type] : nil
        end

        attribute :score do |record|
          record.values.key?(:score) ? record[:score]&.to_f&.round(4) : nil
        end
      end
    end
  end
end
