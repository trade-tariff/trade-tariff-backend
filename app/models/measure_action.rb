class MeasureAction < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :action_code

  set_primary_key [:action_code]

  many_to_one :measure_action_description, key: :action_code,
                                           primary_key: :action_code

  delegate :description, to: :measure_action_description
end
