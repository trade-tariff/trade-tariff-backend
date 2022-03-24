module MeasureConditionPermutations
  module Calculators
    class Matched
      def initialize(measure_sid, measure_conditions)
        @measure_sid = measure_sid
        @measure_conditions = measure_conditions
      end

      def permutation_groups
        [
          Group.new(@measure_sid,
                    'n/a',
                    permutations_for_matched_conditions + permutations_for_unmatched_conditions),
        ]
      end

    private

      def measure_conditions_grouped_by_permutation_key
        @measure_conditions_grouped_by_permutation_key ||=
          @measure_conditions
            .group_by(&:permutation_key)
            .values
      end

      def permutations_for_matched_conditions
        measure_conditions_grouped_by_permutation_key
          .select(&:many?)  # select conditions with multiple matching the same key
          .map(&:first)     # conditions have same key, so only include the first
          .sort_by(&method(:sort_priority))
          .map(&Permutation.method(:new)) # Create permutation for each condition
      end

      def permutations_for_unmatched_conditions
        conditions_grouped_by_condition_code
          .inject([], &method(:calculate_permutations)) # Iteratively combine to compute permutations
          .map(&Permutation.method(:new))
      end

      def conditions_grouped_by_condition_code
        measure_conditions_grouped_by_permutation_key
          .reject(&:many?)  # reject any with more than one condition matching a key
          .flatten          # any remaining only have 1 condition in each group
          .group_by(&:condition_code)
          .sort_by(&:first) # sort on condition code, converts from Hash to Array
          .map(&:last)
      end

      def calculate_permutations(existing_combinations, conditions_for_code)
        # first iteration will have no existin combinations to build upon
        # so just wrap each condition in its own array
        if existing_combinations.none?
          return conditions_for_code.map(&Array.method(:wrap))
        end

        conditions_for_code.flat_map do |condition|
          existing_combinations.map do |combination|
            combination + [condition]
          end
        end
      end

      def sort_priority(condition)
        case condition.measure_condition_class
        when MeasureConditionClassification::DOCUMENT_CLASS then 1
        when MeasureConditionClassification::EXEMPTION_CLASS then 2
        when MeasureConditionClassification::THRESHOLD_CLASS then 3
        else 4
        end
      end
    end
  end
end
