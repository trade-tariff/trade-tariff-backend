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

    INCLUDED_NEGATIVE_ACTIONS = %w[08].freeze

    delegate :measure_sid, to: :@measure

    def initialize(measure)
      @measure = measure
    end

    def permutation_groups
      if matched_measure_conditions?
        Calculators::Matched.new(measure_sid, measure_conditions)
                            .permutation_groups
      else
        Calculators::Unmatched.new(measure_sid, measure_conditions)
                              .permutation_groups
      end
    end

  private

    def measure_conditions
      @measure_conditions ||= @measure.measure_conditions
                                      .reject(&:universal_waiver_applies?)
                                      .reject(&method(:excluded_condition?))
    end

    def matched_measure_conditions?
      measure_conditions
        .group_by(&:permutation_key)
        .values
        .any?(&:many?) # multiple conditions with same key
    end

    def excluded_condition?(condition)
      condition.negative_class? &&
        condition.measure_action.present? &&
        INCLUDED_NEGATIVE_ACTIONS.exclude?(condition.measure_action.action_code)
    end
  end
end
