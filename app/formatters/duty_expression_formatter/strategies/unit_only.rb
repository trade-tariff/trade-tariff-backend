class DutyExpressionFormatter::Strategies::UnitOnly < DutyExpressionFormatter::Strategies::Base
  def call
    [measurement_unit_fragment].compact
  end
end
