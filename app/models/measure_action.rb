class MeasureAction < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :action_code

  set_primary_key [:action_code]

  many_to_one :measure_action_description, key: :action_code,
                                           primary_key: :action_code

  delegate :description, to: :measure_action_description

  APPLY_MEASURE_ACTION_CODES = [
    '01', # Apply the amount of the action (see components)
    '07', # Measure not applicable
    '24', # Entry into free circulation allowed
    '25', # Export allowed
    '26', # Import allowed
    '27', # Apply the mentioned duty
    '28', # Declared subheading allowed
    '29', # Import/export allowed after control
    '34', # Apply exemption/reduction of the anti-dumping duty
    '36', # Apply export refund
  ].freeze

  EXCLUDE_MEASURE_ACTION_CODES = [
    '04', # The entry into free circulation is not allowed
    '05', # Export is not allowed
    '06', # Import is not allowed
    '08', # Declared subheading not allowed
    '09', # Import/export not allowed after control
    '16', # Export refund not applicable
  ].freeze

  def positive_action?
    action_code.in?(APPLY_MEASURE_ACTION_CODES)
  end

  def negative_action?
    action_code.in?(EXCLUDE_MEASURE_ACTION_CODES)
  end
end
