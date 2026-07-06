module TariffKnowledge
  class PublicAtarSearchRefresh
    BATCH_SIZE = 500

    def self.call(...) = new(...).call

    def initialize(goods_nomenclature_item_ids)
      @goods_nomenclature_item_ids = Array(goods_nomenclature_item_ids).compact_blank.uniq
    end

    def call
      return [] if goods_nomenclature_item_ids.empty?

      sids = []
      goods_nomenclature_item_ids.each_slice(BATCH_SIZE) do |item_id_batch|
        goods_nomenclatures = matching_goods_nomenclatures(item_id_batch)
        next if goods_nomenclatures.empty?

        bulk_reindex(goods_nomenclatures)

        sid_batch = goods_nomenclatures.map(&:goods_nomenclature_sid)
        sids.concat(sid_batch)
        ScoreLabelBatchWorker.perform_async(sid_batch)
      end

      sids
    end

  private

    attr_reader :goods_nomenclature_item_ids

    def matching_goods_nomenclatures(item_ids)
      TimeMachine.now do
        index = Search::GoodsNomenclatureIndex.new

        GoodsNomenclature
          .actual
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_item_id: item_ids)
          .eager(index.eager_load)
          .all
      end
    end

    def bulk_reindex(goods_nomenclatures)
      index = Search::GoodsNomenclatureIndex.new
      TradeTariffBackend.search_client.bulk(
        body: goods_nomenclatures.map { |goods_nomenclature| bulk_operation(index, goods_nomenclature) },
      )
    end

    def bulk_operation(index, goods_nomenclature)
      {
        index: {
          _index: index.name,
          _id: index.document_id(goods_nomenclature),
          data: index.serialize_record(goods_nomenclature),
        },
      }
    end
  end
end
