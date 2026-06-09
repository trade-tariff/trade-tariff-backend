module Api
  module Admin
    class TariffKnowledgeCompressedNoteSerializer
      include JSONAPI::Serializer

      set_type :tariff_knowledge_compressed_note
      set_id :goods_nomenclature_sid

      attributes :goods_nomenclature_sid,
                 :goods_nomenclature_item_id,
                 :producline_suffix,
                 :goods_nomenclature_type,
                 :content,
                 :metadata,
                 :context_hash,
                 :needs_review,
                 :approved,
                 :manually_edited,
                 :stale,
                 :expired,
                 :generated_at,
                 :created_at,
                 :updated_at
    end
  end
end
