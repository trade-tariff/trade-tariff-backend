module GreenLanesUpdatesPublisher
  class UpdateNotificationsCreator
    def initialize(updates)
      @updates = updates
    end

    def call
      if @updates.any?
        @updates.each do |update|
          notification = GreenLanes::UpdateNotification.new(regulation_id: update.regulation_id,
                                                            regulation_role: update.regulation_role,
                                                            measure_type_id: update.measure_type_id,
                                                            status: update.status,
                                                            theme_id: update.theme_id)

          if notification.valid?
            notification.save
          end
        end
      end
    end
  end
end
