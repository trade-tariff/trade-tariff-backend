module GreenLanesUpdatesPublisher
  class GreenLanesUpdate
    attr_reader :regulation_id, :regulation_role, :measure_type_id, :status

    def initialize(regulation_id, regulation_role, measure_type_id)
      @regulation_id = regulation_id
      @regulation_role = regulation_role
      @measure_type_id = measure_type_id
      @status = 0
    end
  end
end
