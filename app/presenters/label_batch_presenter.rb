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

  def as_json(_options = {})
    map do |goods_nomenclature|
      description = goods_nomenclature.classification_description

      presented = goods_nomenclature.as_json(
        only: [
          :goods_nomenclature_item_id,
        ],
      )
      presented['original_description'] = description

      presented
    end
  end
end
