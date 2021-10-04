class DutyExpression < Sequel::Model
  MEURSING_DUTY_EXPRESSION_IDS = %w[12 14 21 25 27 29].freeze

  MEURSING_DUTY_EXPRESSION_IDS_MEASURE_TYPE_MAPPING = {
    '12' => '674', # + agricultural component
    '14' => '674', # + reduced agricultural component
    '21' => '672', # + additional duty on sugar
    '25' => '672', # + reduced additional duty on sugar
    '27' => '673', # + additional duty on flour
    '29' => '673', # + reduced additional duty on flour
  }.freeze

  plugin :time_machine
  plugin :oplog, primary_key: :duty_expression_id

  set_primary_key [:duty_expression_id]

  one_to_one :duty_expression_description

  delegate :abbreviation, :description, to: :duty_expression_description

  def meursing_measure_type_id
    MEURSING_DUTY_EXPRESSION_IDS_MEASURE_TYPE_MAPPING[duty_expression_id]
  end
end
