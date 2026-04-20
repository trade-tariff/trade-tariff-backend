class GoodsNomenclatureIntercept < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail

  set_primary_key [:goods_nomenclature_sid]
  unrestrict_primary_key

  def validate
    super
    validates_presence :goods_nomenclature_sid
    validates_includes [true, false], :excluded
  end
end
