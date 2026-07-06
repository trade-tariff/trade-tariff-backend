module TariffKnowledge
  class PublicAtarSearchRefresh
    BATCH_SIZE = 500

    def self.call(...) = new(...).call

    def initialize(goods_nomenclature_item_ids)
      @goods_nomenclature_item_ids = Array(goods_nomenclature_item_ids).compact_blank.uniq
    end

    def call
      return [] if goods_nomenclature_item_ids.empty?

      goods_nomenclatures = matching_goods_nomenclatures
      goods_nomenclatures.each { |goods_nomenclature| reindex(goods_nomenclature) }

      sids = goods_nomenclatures.map(&:goods_nomenclature_sid)
      sids.each_slice(BATCH_SIZE) { |batch| ScoreLabelBatchWorker.perform_async(batch) }
      sids
    end

  private

    attr_reader :goods_nomenclature_item_ids

    def matching_goods_nomenclatures
      TimeMachine.now do
        index = Search::GoodsNomenclatureIndex.new

        GoodsNomenclature
          .actual
          .with_leaf_column
          .where(goods_nomenclatures__goods_nomenclature_item_id: goods_nomenclature_item_ids)
          .eager(index.eager_load)
          .all
      end
    end

    def reindex(goods_nomenclature)
      TradeTariffBackend.search_client.index(
        Search::GoodsNomenclatureIndex,
        goods_nomenclature,
      )
    end
  end
end
