module GreenLanes
  class PermutationCalculatorService
    def initialize(measures)
      @measures = measures
    end

    def call
      [@measures]
    end
  end
end
