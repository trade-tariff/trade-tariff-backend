class Guide < Sequel::Model
  many_to_many :goods_nomenclatures, left_key: :guide_id,
                                     right_key: :goods_nomenclature_sid,
                                     right_primary_key: :goods_nomenclature_sid,
                                     left_primary_key: :id,
                                     join_table: :guides_goods_nomenclatures
end
