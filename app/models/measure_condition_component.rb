class MeasureConditionComponent < Sequel::Model
  plugin :oplog, primary_key: %i[measure_condition_sid
                                 duty_expression_id]

  set_primary_key %i[measure_condition_sid duty_expression_id]

  include Componentable

  one_to_one :measure_condition, key: :measure_condition_sid,
                                 primary_key: :measure_condition_sid
end
