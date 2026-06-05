module TariffKnowledge
  class DeclarableContext < Sequel::Model(:tariff_knowledge_declarable_contexts)
    include GeneratedContentLifecycle

    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :not_nil
    plugin :has_paper_trail

    set_primary_key [:goods_nomenclature_sid]
    unrestrict_primary_key

    many_to_one :goods_nomenclature,
                key: :goods_nomenclature_sid,
                primary_key: :goods_nomenclature_sid

    dataset_module do
      def by_sids(sids)
        where(goods_nomenclature_sid: sids)
      end

      def by_item_ids(item_ids)
        where(goods_nomenclature_item_id: item_ids)
      end
    end
  end
end
