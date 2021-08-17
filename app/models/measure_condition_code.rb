class MeasureConditionCode < Sequel::Model
  ENTRY_PRICE_SYSTEM_CODE = 'V'.freeze

  plugin :time_machine
  plugin :oplog, primary_key: :condition_code

  set_primary_key [:condition_code]

  one_to_one :measure_condition_code_description, key: :condition_code,
                                                  primary_key: :condition_code

  delegate :description, to: :measure_condition_code_description
end
