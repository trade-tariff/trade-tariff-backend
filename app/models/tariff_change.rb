class TariffChange < Sequel::Model
  plugin :auto_validations, not_null: :presence
  plugin :timestamps, update_on_create: true

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid

  def self.delete_for(operation_date:)
    TariffChange.where(operation_date: operation_date).delete
  end
end
