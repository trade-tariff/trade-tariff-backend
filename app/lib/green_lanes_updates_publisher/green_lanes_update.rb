module GreenLanesUpdatesPublisher
  class GreenLanesUpdate
    attr_reader :regulation_id, :regulation_role, :measure_type_id, :theme, :theme_id, :status

    def initialize(regulation_id, regulation_role, measure_type_id, status)
      @regulation_id = regulation_id
      @regulation_role = regulation_role
      @measure_type_id = measure_type_id
      @status = status
    end

    def status=(value)
      @status = value
    end

    def theme=(value)
      @theme = value
    end

    def theme_id=(value)
      @theme_id = value
    end
  end
end
