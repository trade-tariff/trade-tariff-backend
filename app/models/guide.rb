class Guide < Sequel::Model
  many_to_many :goods_nomenclatures, left_key: :guide_id,
                                     right_key: :goods_nomenclature_sid,
                                     join_table: :guides_goods_nomenclatures
end
