module MeasureConditionPermutations
  class Calculator
    def initialize(measure)
      @measure = measure
    end

    def permutation_groups
      @measure.measure_conditions
              .group_by(&:condition_code)
              .map(&method(:group_for_condition_code))
    end

  private

    def group_for_condition_code(condition_code, conditions)
      Group.new(@measure.measure_sid, condition_code, conditions)
    end
  end
end
