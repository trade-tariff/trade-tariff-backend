class DutyExpressionFormatter
  extend DutyExpressionPrettifier

  class << self
    def format(opts = {})
      context = Context.build(opts)
      output = OutputBuilder.call(context)

      result = output.join(' ').html_safe

      if context.resolved_meursing_component
        "<strong>#{result}</strong>"
      else
        result
      end
    end
  end
end
