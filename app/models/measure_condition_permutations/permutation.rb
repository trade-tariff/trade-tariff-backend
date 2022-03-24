require 'digest'

module MeasureConditionPermutations
  class Permutation
    attr_reader :id, :measure_conditions

    delegate :length, to: :measure_conditions

    def initialize(measure_conditions)
      @measure_conditions = Array.wrap(measure_conditions)
      @id = generate_id
    end

    def remove_duplicate_conditions
      @measure_conditions = measure_conditions.uniq
      @id = generate_id

      self
    end

    def measure_condition_ids
      measure_conditions.map(&:measure_condition_sid)
    end

    def ==(other)
      other.class == self.class &&
        measure_condition_ids == other.measure_condition_ids
    end

  private

    def generate_id
      Digest::MD5.hexdigest \
        @measure_conditions.map(&:measure_condition_sid).join('-')
    end
  end
end
