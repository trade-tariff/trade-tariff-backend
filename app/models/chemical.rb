class Chemical < Sequel::Model
  many_to_many :goods_nomenclatures, join_table: :chemicals_goods_nomenclatures,
                                     right_key: :goods_nomenclature_sid,
                                     right_primary_key: :goods_nomenclature_sid,
                                     left_key: :chemical_id,
                                     left_primary_key: :id,
                                     use_optimized: true
  one_to_many :chemical_names

  def name
    chemical_names.map(&:name).join('; ')
  end

  def goods_nomenclature_ids
    goods_nomenclatures.map(&:goods_nomenclature_sid)
  end

  def chemical_name_ids
    chemical_names.map(&:id)
  end
end
