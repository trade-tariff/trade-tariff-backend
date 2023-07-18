module Api
  module V2
    module Measures
      class MeasureConditionPresenter < WrapDelegator
        def initialize(measure, measure_condition)
          super(measure_condition)

          @measure = measure
          @measure_condition = measure_condition
        end

        def measure_condition_components
          @measure_condition_components ||= MeasureConditionComponentPresenter.wrap(measure, super)
        end

        def self.wrap(measure, measure_conditions)
          measure_conditions.map do |measure_condition|
            new(measure, measure_condition)
          end
        end

        private

        attr_reader :measure, :measure_condition
      end
    end
  end
end
