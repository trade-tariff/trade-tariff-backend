module Api
  module V2
    module Measures
      class DutyExpressionSerializer
        include JSONAPI::Serializer

        set_type :duty_expression

        attributes :base, :formatted_base, :verbose_duty
      end
    end
  end
end
