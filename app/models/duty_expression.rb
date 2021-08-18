class DutyExpression < Sequel::Model
  MEURSING_DUTY_EXPRESSION_IDS  = %w[12 14 21 25 27 29].freeze

  plugin :time_machine
  plugin :oplog, primary_key: :duty_expression_id

  set_primary_key [:duty_expression_id]

  one_to_one :duty_expression_description

  delegate :abbreviation, :description, to: :duty_expression_description
end
