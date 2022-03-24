module MeasureConditionPermutations
  module Calculators
    class Unmatched
      def initialize(measure_sid, measure_conditions)
        @measure_sid = measure_sid
        @measure_conditions = measure_conditions
      end

      def permutation_groups
        @measure_conditions
          .group_by(&:condition_code)
          .map(&method(:build_groups))
      end

    private

      def build_groups(condition_code, conditions)
        Group.new(@measure_sid,
                  condition_code,
                  conditions.map(&Permutation.method(:new)))
      end
    end
  end
end
