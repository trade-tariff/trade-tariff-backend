class MeasureComponent < Sequel::Model
  plugin :oplog, primary_key: %i[measure_sid duty_expression_id]

  set_primary_key %i[measure_sid duty_expression_id]

  include Componentable

  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid
end
