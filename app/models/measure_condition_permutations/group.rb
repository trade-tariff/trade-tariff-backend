module MeasureConditionPermutations
  class Group
    # Permutations are grouped according to condition code

    attr_reader :id, :condition_code

    def initialize(measure_sid, condition_code, conditions)
      @measure_sid = measure_sid
      @condition_code = condition_code
      @conditions = conditions
      @id = "#{measure_sid}-#{condition_code}"
    end

    def permutations
      @permutations = compute_permutations.map(&:remove_duplicate_conditions)
                                          .map(&method(:remove_superset_permutations))
    end

    def permutation_ids
      permutations.map(&:id)
    end

  private

    def compute_permutations
      [Permutation.new(@conditions)]
    end

    def remove_superset_permutations(permutations)
      # FIXME: To be implemented
      permutations
    end
  end
end
