module TariffKnowledge
  class DeclarableNodeLoader
    BATCH_SIZE = 500

    def self.call
      new.call
    end

    def call
      TimeMachine.now do
        GoodsNomenclature.actual
                         .with_leaf_column
                         .declarable
                         .non_hidden
                         .paged_each(rows_per_fetch: BATCH_SIZE)
                         .each_slice(BATCH_SIZE) do |goods_nomenclatures|
          upsert_goods_nomenclature_nodes(goods_nomenclatures.map(&:sti_cast))
        end
        remove_hidden_goods_nomenclature_nodes
      end
    end

  private

    def remove_hidden_goods_nomenclature_nodes
      Node.goods_nomenclatures
          .where(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes)
          .delete
    end

    def upsert_goods_nomenclature_nodes(goods_nomenclatures)
      rows = goods_nomenclatures.map { |goods_nomenclature| node_row(goods_nomenclature) }
      return if rows.empty?

      Node.dataset
          .insert_conflict(target: :key, update: update_values)
          .multi_insert(rows)
    end

    def node_row(goods_nomenclature)
      now = Time.zone.now

      {
        node_type: Node::GOODS_NOMENCLATURE,
        key: "goods_nomenclature:#{goods_nomenclature.goods_nomenclature_sid}",
        title: goods_nomenclature.goods_nomenclature_item_id,
        content: nil,
        metadata: Sequel.pg_jsonb({}),
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        producline_suffix: goods_nomenclature.producline_suffix,
        goods_nomenclature_type: goods_nomenclature.goods_nomenclature_class,
        validity_start_date: goods_nomenclature.validity_start_date,
        validity_end_date: goods_nomenclature.validity_end_date,
        created_at: now,
        updated_at: now,
      }
    end

    def update_values
      {
        title: Sequel[:excluded][:title],
        content: Sequel[:excluded][:content],
        metadata: Sequel[:excluded][:metadata],
        goods_nomenclature_sid: Sequel[:excluded][:goods_nomenclature_sid],
        goods_nomenclature_item_id: Sequel[:excluded][:goods_nomenclature_item_id],
        producline_suffix: Sequel[:excluded][:producline_suffix],
        goods_nomenclature_type: Sequel[:excluded][:goods_nomenclature_type],
        validity_start_date: Sequel[:excluded][:validity_start_date],
        validity_end_date: Sequel[:excluded][:validity_end_date],
        updated_at: Sequel[:excluded][:updated_at],
      }
    end
  end
end
