class GoodsNomenclatureGroup < Sequel::Model
  plugin :oplog, primary_key: %i[goods_nomenclature_group_id
                                 goods_nomenclature_group_type]

  set_primary_key %i[goods_nomenclature_group_id goods_nomenclature_group_type]
end
