class SpqDutyExpressionFormatter
  extend DutyExpressionPrettifier

  class << self
    def format(component)
      duty_amount = prettify(component.duty_amount)

      "(£#{duty_amount} - SPR discount) / vol% / hl"
    end
  end
end
