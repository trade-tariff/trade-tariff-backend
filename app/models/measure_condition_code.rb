class MeasureConditionCode < Sequel::Model
  ENTRY_PRICE_SYSTEM_CODE = 'V'.freeze
  REQUIREMENT_CONDITION_CODE_OPERATORS = {
    "E": '=<',
    "F": '=>',
    "G": '=>',
    "I": '=<',
    "J": '>',
    "L": '>',
    "M": '=>',
    "N": '=>',
    "O": '>',
    "R": '=>',
    "U": '>',
    "V": '=>',
    "X": '>',
  }.freeze

  plugin :time_machine
  plugin :oplog, primary_key: :condition_code

  set_primary_key [:condition_code]

  one_to_one :measure_condition_code_description, key: :condition_code,
                                                  primary_key: :condition_code

  delegate :description, to: :measure_condition_code_description

  def requirement_operator
    REQUIREMENT_CONDITION_CODE_OPERATORS[condition_code&.to_sym]
  end
end
