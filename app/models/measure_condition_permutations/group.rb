module MeasureConditionPermutations
  class Group
    attr_reader :id, :condition_code, :permutations

    delegate :length, to: :permutations

    def initialize(measure_sid, condition_code, permutations)
      @measure_sid = measure_sid
      @condition_code = condition_code
      @permutations = permutations
      @id = "#{measure_sid}-#{condition_code}"
    end

    def permutation_ids
      permutations.map(&:id)
    end
  end
end
