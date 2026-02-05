class LabelBatchPresenter < SimpleDelegator
  def initialize(batch)
    @batch = batch

    super
  end

  def goods_nomenclature_for(goods_nomenclature_item_id)
    find do |gn|
      gn.goods_nomenclature_item_id == goods_nomenclature_item_id
    end
  end

  def to_json(*_args)
    map { |goods_nomenclature|
      {
        'commodity_code' => goods_nomenclature.goods_nomenclature_item_id,
        'description' => contextual_description_for(goods_nomenclature),
      }
    }.to_json
  end

  def contextual_description_for(goods_nomenclature)
    SelfTextLookupService.lookup(goods_nomenclature.goods_nomenclature_item_id).presence ||
      goods_nomenclature.ancestor_chain_description
  end
end
