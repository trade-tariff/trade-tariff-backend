class GoodsNomenclatureLabel < Sequel::Model(Sequel[:goods_nomenclature_labels].qualify(:uk))
  plugin :oplog, primary_key: :goods_nomenclature_sid, materialized: true, oplog_table: Sequel[:goods_nomenclature_labels_oplog].qualify(:uk)
  plugin :time_machine
  plugin :auto_validations, not_null: :presence

  set_primary_key [:goods_nomenclature_sid]

  attr_accessor :goods_nomenclature

  def validate
    super

    validates_presence :goods_nomenclature_sid
    validates_presence :goods_nomenclature_type
    validates_presence :goods_nomenclature_item_id
    validates_presence :producline_suffix
    validates_presence :labels
    validate_uniqueness_of_sid
  end

  dataset_module do
    def by_sid(sid)
      where(goods_nomenclature_sid: sid).actual
    end
  end

  private

  def before_create
    self.validity_start_date = goods_nomenclature.validity_start_date
    self.validity_end_date   = goods_nomenclature.validity_end_date
    self.goods_nomenclature_item_id = goods_nomenclature.goods_nomenclature_item_id
    self.producline_suffix = goods_nomenclature.producline_suffix
    self.goods_nomenclature_type = goods_nomenclature.class.name
    super
  end

  def validate_uniqueness_of_sid
    exists = self.class.by_sid(goods_nomenclature_sid).any?

    if exists
      errors.add(:goods_nomenclature_sid, 'A label for this goods_nomenclature_sid already exists for the specified validity period')
    end
  end
end
