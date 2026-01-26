class FullChemical < Sequel::Model
  plugin :identification
  plugin :timestamps
  plugin :auto_validations, not_null: :presence

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   foreign_key: :goods_nomenclature_sid,
                                   graph_use_association_block: true do |ds|
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
    def with_filter(filters)
      return [] if filters.empty?

      goods_nomenclature_sid = filters[:goods_nomenclature_sid]
      goods_nomenclature_item_id = filters[:goods_nomenclature_item_id]
      cus = filters[:cus]
      cas_rn = filters[:cas_rn]
      producline_suffix = filters[:producline_suffix]

      select_all(:full_chemicals)
        .join(:goods_nomenclatures, goods_nomenclature_sid: :goods_nomenclature_sid)
        .by_sid(goods_nomenclature_sid)
        .by_code(goods_nomenclature_item_id)
        .by_cus(cus)
        .by_cas_rn(cas_rn)
        .by_suffix(producline_suffix)
        .where(GoodsNomenclature.validity_dates_filter)
        .all
    end

    def by_sid(goods_nomenclature_sid)
      return self if goods_nomenclature_sid.blank?

      where(Sequel.qualify(table_name, :goods_nomenclature_sid) => goods_nomenclature_sid)
    end

    def by_code(goods_nomenclature_item_id)
      return self if goods_nomenclature_item_id.blank?

      where(Sequel.qualify(table_name, :goods_nomenclature_item_id) => goods_nomenclature_item_id)
    end

    def by_suffix(producline_suffix)
      return self if producline_suffix.blank?

      where(Sequel.qualify(table_name, :producline_suffix) => producline_suffix)
    end

    def by_cus(cus)
      return self if cus.blank?

      where(Sequel.qualify(table_name, :cus) => cus)
    end

    def by_cas_rn(cas_rn)
      return self if cas_rn.blank?

      where(Sequel.qualify(table_name, :cas_rn) => cas_rn)
    end

    delegate :table_name, to: :model
  end
end
