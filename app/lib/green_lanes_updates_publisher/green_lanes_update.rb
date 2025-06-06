module GreenLanesUpdatesPublisher
  class GreenLanesUpdate
    attr_accessor :theme, :theme_id, :status
    attr_reader :regulation_id, :regulation_role, :measure_type_id

    def initialize(regulation_id, regulation_role, measure_type_id, status)
      @regulation_id = regulation_id
      @regulation_role = regulation_role
      @measure_type_id = measure_type_id
      @status = status
    end
  end
end
