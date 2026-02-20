class GoodsNomenclatureSuccessor < Sequel::Model
  plugin :oplog, primary_key: %i[goods_nomenclature_sid
                                 absorbed_goods_nomenclature_item_id
                                 absorbed_productline_suffix
                                 goods_nomenclature_item_id
                                 productline_suffix]

  set_primary_key %i[goods_nomenclature_sid
                     absorbed_goods_nomenclature_item_id
                     absorbed_productline_suffix
                     goods_nomenclature_item_id
                     productline_suffix]

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid
  many_to_one :absorbed_goods_nomenclature, primary_key: %i[goods_nomenclature_item_id
                                                            producline_suffix],
                                            key: %i[absorbed_goods_nomenclature_item_id
                                                    absorbed_productline_suffix],
                                            class: 'GoodsNomenclature'
end
