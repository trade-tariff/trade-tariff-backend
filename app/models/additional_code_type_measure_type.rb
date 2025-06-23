class AdditionalCodeTypeMeasureType < Sequel::Model
  plugin :oplog, primary_key: %i[measure_type_id additional_code_type_id], materialized: true

  set_primary_key %i[measure_type_id additional_code_type_id]

  many_to_one :measure_type
  many_to_one :additional_code_type

  class << self
    def refresh!(concurrently: false)
      db.refresh_view(:additional_code_type_measure_types, concurrently:)
    end
  end
end
