class FullChemical < Sequel::Model
  plugin :timestamps
  plugin :auto_validations, not_null: :presence

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   foreign_key: :goods_nomenclature_sid do |ds|
                                     ds.with_actual(GoodsNomenclature)
                                   end

  def validate
    super

    validates_presence :cus
    validates_presence :goods_nomenclature_sid
    validates_presence :goods_nomenclature_item_id
    validates_presence :producline_suffix
    validates_presence :name
  end

  dataset_module do
    def by_code(goods_nomenclature_item_id)
      where(goods_nomenclature_item_id:)
    end

    def by_suffix(producline_suffix)
      where(producline_suffix:)
    end

    def by_cus(cus)
      where(cus:)
    end

    def by_cas_rn(cas_rn)
      where(cas_rn:)
    end
  end
end
