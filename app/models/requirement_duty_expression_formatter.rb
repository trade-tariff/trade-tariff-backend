class RequirementDutyExpressionFormatter
  extend DutyExpressionPrettifier

  class << self
    def format(opts = {})
      context = Context.build(opts)

      OutputBuilder.call(context).join(' ').html_safe
    end
  end
end
