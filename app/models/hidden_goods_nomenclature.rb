class HiddenGoodsNomenclature < Sequel::Model
  plugin :timestamps

  set_dataset order(Sequel.asc(:goods_nomenclature_item_id))

  set_primary_key [:goods_nomenclature_item_id]

  validates do
    presence_of :goods_nomenclature_item_id
  end

  def self.codes
    all.map(&:goods_nomenclature_item_id)
  end
end
