module Api
  module V2
    module Measures
      class DutyExpressionSerializer
        include JSONAPI::Serializer

        set_type :duty_expression

        attribute :base, &:duty_expression
        attribute :formatted_base, &:formatted_duty_expression
        attribute :verbose_duty, &:verbose_duty_expression
      end
    end
  end
end
