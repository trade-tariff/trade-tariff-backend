class DutyExpressionFormatter::OutputBuilder
  DESCRIPTION_ONLY_EXPRESSION_IDS = %w[12 14 37 40 41 42 43 44 21 25 27 29].freeze
  DESCRIPTION_AMOUNT_EXPRESSION_IDS = %w[02 04 15 17 19 20 36].freeze

  class << self
    def call(context)
      new(context).call
    end
  end

  def initialize(context)
    @context = context
  end

  def call
    strategy_for(context).call
  end

  private

  attr_reader :context

  def strategy_for(context)
    if context.duty_expression_id == '99'
      DutyExpressionFormatter::Strategies::UnitOnly.new(context)
    elsif DESCRIPTION_ONLY_EXPRESSION_IDS.include?(context.duty_expression_id)
      DutyExpressionFormatter::Strategies::DescriptionOnly.new(context)
    elsif DESCRIPTION_AMOUNT_EXPRESSION_IDS.include?(context.duty_expression_id)
      DutyExpressionFormatter::Strategies::DescriptionAmount.new(context)
    else
      DutyExpressionFormatter::Strategies::Default.new(context)
    end
  end
end
