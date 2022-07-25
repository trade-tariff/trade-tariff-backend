module MeasureConditionPermutations
  class Permutation
    include ContentAddressableId

    content_addressable_fields 'measure_condition_ids'

    attr_reader :measure_conditions

    delegate :length, to: :measure_conditions

    def initialize(measure_conditions)
      @measure_conditions = Array.wrap(measure_conditions)
    end

    def remove_duplicate_conditions
      @measure_conditions = measure_conditions.uniq
      @id = nil

      self
    end

    def measure_condition_ids
      measure_conditions.map(&:measure_condition_sid)
    end

    def ==(other)
      other.class == self.class &&
        measure_condition_ids == other.measure_condition_ids
    end
  end
end
