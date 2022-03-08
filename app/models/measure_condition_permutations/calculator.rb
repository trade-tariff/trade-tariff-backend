module MeasureConditionPermutations
  class Calculator
    # There are 2 rules for calculating permutations
    #
    # When there are conditions with matching permutation_keys, then a single
    # permutation group is provided with all permutations
    #
    # If there are no conditions with matching permutation key, then generate
    # one group per condition code, with a separate permutation per condition
    # within it

    def initialize(measure)
      @measure = measure
    end

    def measure_conditions
      @measure_conditions = @measure.measure_conditions
                                    .reject(&:universal_waiver_applies?)
                                    .reject(&:negative_class?)
    end

    def permutation_groups
      if matched_measure_conditions_in_permutation_key_groups.any?
        groups_when_there_are_matched_conditions
      else
        groups_when_no_matched_conditions
      end
    end

  private

    def measure_conditions_by_permutation_key
      @measure_conditions_by_permutation_key =
        measure_conditions
          .select(&:permutation_key) # ignore those we can't calculate key for
          .group_by(&:permutation_key)
    end

    def groups_when_there_are_matched_conditions
      [
        Group.new(@measure.measure_sid,
                  'n/a',
                  permutations_for_matched_conditions + permutations_for_unmatched_conditions),
      ]
    end

    def matched_measure_conditions_in_permutation_key_groups
      measure_conditions_by_permutation_key.values.select(&:many?)
    end

    def unmatched_measure_conditions
      measure_conditions_by_permutation_key
        .values
        .reject(&:many?) # reject any with more than one condition matching a key
        .flatten # any remaining only have 1 condition in each group
    end

    def permutations_for_matched_conditions
      matched_measure_conditions_in_permutation_key_groups
        .map(&:first) # conditions match, so only include the first
        .sort_by(&method(:sort_priority))
        .map(&Permutation.method(:new)) # Create permutation for each condition
    end

    def permutations_for_unmatched_conditions
      groups_of_conditions_by_code
        .inject([], &method(:combine_conditions_in_group_with_existing_combinations)) # Compute all combinations
        .map(&Permutation.method(:new))
    end

    def groups_of_conditions_by_code
      unmatched_measure_conditions
        .group_by(&:condition_code)
        .sort_by(&:first) # sort on condition code, converts from Hash to Array
        .map(&:last)
    end

    def combine_conditions_in_group_with_existing_combinations(combinations, conditions_for_code)
      # first iteration will have no existin combinations to build upon
      return conditions_for_code.map(&Array.method(:wrap)) if combinations.none?

      conditions_for_code.flat_map do |condition|
        combinations.map do |combination|
          combination + [condition]
        end
      end
    end

    def groups_when_no_matched_conditions
      measure_conditions
        .group_by(&:condition_code)
        .map(&method(:group_with_permutation_per_condition))
    end

    def group_with_permutation_per_condition(condition_code, conditions)
      Group.new(@measure.measure_sid,
                condition_code,
                conditions.map(&Permutation.method(:new)))
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
