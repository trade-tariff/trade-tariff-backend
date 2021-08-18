class MeasureTypeDescription < Sequel::Model
  set_primary_key [:measure_type_id]
  plugin :oplog, primary_key: :measure_type_id

  one_to_one :measure_type, key: :measure_type_id,
                            foreign_key: :measure_type_id

  def to_s
    description
  end
end
