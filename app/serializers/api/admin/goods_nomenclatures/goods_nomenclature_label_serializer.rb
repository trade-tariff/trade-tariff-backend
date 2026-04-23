module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureLabelSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature_label

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :goods_nomenclature_type,
                   :producline_suffix,
                   :needs_review,
                   :approved,
                   :stale,
                   :manually_edited,
                   :expired,
                   :created_at,
                   :updated_at,
                   :context_hash,
                   :description,
                   :original_description,
                   :synonyms,
                   :colloquial_terms,
                   :known_brands,
                   :description_score,
                   :synonym_scores,
                   :colloquial_term_scores,
                   :score

        attribute :labels do |label|
          label.labels || {}
        end

        attribute :has_self_text do |label|
          GoodsNomenclatureSelfText.where(goods_nomenclature_sid: label.goods_nomenclature_sid).any?
        end
      end
    end
  end
end
