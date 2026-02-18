class LabelBatchPresenter < SimpleDelegator
  def initialize(batch)
    @batch = batch
    @self_texts = load_self_texts(batch)

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
    @self_texts[goods_nomenclature.goods_nomenclature_sid].presence ||
      DescriptionNormaliser.call(goods_nomenclature.ancestor_chain_description)
  end

  private

  def load_self_texts(batch)
    sids = batch.map(&:goods_nomenclature_sid)
    GoodsNomenclatureSelfText
      .where(goods_nomenclature_sid: sids)
      .select_map(%i[goods_nomenclature_sid self_text])
      .to_h
  end
end
