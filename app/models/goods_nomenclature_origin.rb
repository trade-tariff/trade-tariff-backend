class GoodsNomenclatureOrigin < Sequel::Model
  plugin :oplog, primary_key: %i[goods_nomenclature_sid
                                 derived_goods_nomenclature_item_id
                                 derived_productline_suffix
                                 goods_nomenclature_item_id
                                 productline_suffix]

  set_primary_key %i[goods_nomenclature_sid
                     derived_goods_nomenclature_item_id
                     derived_productline_suffix
                     goods_nomenclature_item_id
                     productline_suffix]

  # The new goods nomenclature
  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid

  # The goods nomenclature where the new goods nomenclature used to be in the tariff
  many_to_one :derived_goods_nomenclature, primary_key: %i[goods_nomenclature_item_id producline_suffix],
                                           key: %i[derived_goods_nomenclature_item_id derived_productline_suffix],
                                           class: 'GoodsNomenclature'

private

  def after_create
    super
    GoodsNomenclatureChangeAccumulator.push!(
      sid: goods_nomenclature_sid,
      change_type: :moved,
      item_id: goods_nomenclature_item_id,
    )
  end
end
