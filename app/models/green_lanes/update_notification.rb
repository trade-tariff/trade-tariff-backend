module GreenLanes
  class UpdateNotification < Sequel::Model(:green_lanes_update_notifications)
    class NotificationStatus
      CREATED = 0
      UPDATED = 1
      EXPIRED = 2
      INACTIVE = 9
    end

    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :association_pks
    plugin :association_dependencies

    many_to_one :measure_type, class: :MeasureType
    many_to_one :base_regulation, class: :BaseRegulation,
                                  key: %i[regulation_id regulation_role]
    many_to_one :modification_regulation, class: :ModificationRegulation,
                                          key: %i[regulation_id regulation_role]

    def regulation
      case regulation_role
      when nil then nil
      when ::Measure::MODIFICATION_REGULATION_ROLE then modification_regulation
      else base_regulation
      end
    end

    def regulation=(regulation)
      case regulation
      when nil
        self.base_regulation = self.modification_regulation = nil
      when ModificationRegulation
        self.base_regulation = nil
        self.modification_regulation = regulation
      else
        self.modification_regulation = nil
        self.base_regulation = regulation
      end
    end
  end
end
