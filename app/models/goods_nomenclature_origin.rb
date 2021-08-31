class GoodsNomenclatureOrigin < Sequel::Model
  plugin :oplog, primary_key: %i[oid
                                 goods_nomenclature_sid
                                 derived_goods_nomenclature_item_id
                                 derived_productline_suffix
                                 goods_nomenclature_item_id
                                 productline_suffix]

  set_primary_key %i[goods_nomenclature_sid
                     derived_goods_nomenclature_item_id
                     derived_productline_suffix
                     goods_nomenclature_item_id
                     productline_suffix]

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid
end
