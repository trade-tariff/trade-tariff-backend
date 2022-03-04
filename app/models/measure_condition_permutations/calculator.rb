module MeasureConditionPermutations
  class Calculator
    # There are 2 rules for calculating permutations
    #
    # When there are conditions with the same permutation_key, but with different
    # condition codes, then a single permutation group is provided with all
    # permutations calculated
    #
    # If there are no conditions with the same permutation key but different
    # condition codes, then each code gets its own group, with each group
    # having a separate permutation per condition, with a reference to just that
    # measure condition

    delegate :measure_conditions, to: :@measure

    def initialize(measure)
      @measure = measure
    end

    def permutation_groups
      if any_matched_measure_conditions?
        matched_conditions_in_single_permutation_group
      else
        unmatched_conditions_in_multiple_permutation_groups
      end
    end

  private

    def group_for_code(condition_code, permutations)
      Group.new(@measure.measure_sid, condition_code, permutations)
    end

    def conditions_grouped_by_code
      measure_conditions.group_by(&:condition_code)
    end

    def unmatched_conditions_in_multiple_permutation_groups
      conditions_grouped_by_code.map do |condition_code, conditions|
        permutations = conditions.map(&Permutation.method(:new))

        group_for_code condition_code, permutations
      end
    end

    def any_matched_measure_conditions?
      matched_measure_conditions.values.any?(&:many?)
    end

    def matched_measure_conditions
      @matched_measure_conditions =
        measure_conditions.select(&:permutation_key).group_by(&:permutation_key)
    end

    def matched_conditions_in_single_permutation_group
      [
        Group.new(@measure.measure_sid,
                  'n/a',
                  repeated_condition_permutations + unrepeated_condition_permutations),
      ]
    end

    def repeated_condition_permutations
      matched_measure_conditions.values # grab the conditions themselves
                                .select(&:many?) # fetch conditions with repeated permutation keys
                                .map(&:first) # grab just the first for any key since they're the same
                                .map(&Permutation.method(:new)) # Create permutation for each one
    end

    def unrepeated_condition_permutations
      # FIXME: Needs refactor

      unrepeated = matched_measure_conditions.values # grab the conditions themselves
                                             .reject(&:many?) # fetch conditions without repeated permutation keys
                                             .map(&:first)
                                             .group_by(&:condition_code)

      reversed_condition_groups = unrepeated.sort_by(&:first).reverse.map(&:last)

      reversed_condition_groups.inject([]) do |combinations, conditions|
        if combinations.any?
          conditions.flat_map do |condition|
            combinations.map do |combination|
              [condition] + combination
            end
          end
        else
          conditions.to_a.map(&Array.method(:wrap))
        end
      end.map(&Permutation.method(:new))
    end
  end
end
