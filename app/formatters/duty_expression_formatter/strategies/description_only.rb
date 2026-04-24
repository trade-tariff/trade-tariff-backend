class DutyExpressionFormatter::Strategies::DescriptionOnly < DutyExpressionFormatter::Strategies::Base
  def call
    [duty_expression_text_fragment].compact
  end
end
