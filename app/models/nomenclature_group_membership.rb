class NomenclatureGroupMembership < Sequel::Model
  plugin :oplog, primary_key: %i[goods_nomenclature_sid
                                 goods_nomenclature_group_id
                                 goods_nomenclature_group_type
                                 goods_nomenclature_item_id
                                 validity_start_date]

  set_primary_key %i[goods_nomenclature_sid goods_nomenclature_group_id
                     goods_nomenclature_group_type goods_nomenclature_item_id
                     validity_start_date]
end
