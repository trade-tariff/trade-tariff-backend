class QuotaEvent
  EVENTS = %w[exhaustion balance critical reopening unblocking unsuspension].freeze

  # Generate a UNION query of all quota event types for a specific quota definition
  def self.for_quota_definition(quota_sid, point_in_time)
    event_queries = EVENTS.map { |event_type| for_event(event_type, quota_sid, point_in_time) }

    event_queries.inject { |combined_query, event_query|
      combined_query.union(event_query, from_self: true)
    }.order(Sequel.desc(:occurrence_timestamp), Sequel.desc(:event_type))
  end

  def self.last_for(quota_sid, point_in_time)
    event = for_quota_definition(quota_sid, point_in_time).first

    if event.present?
      event_class_for(event[:event_type])
    else
      NullObject.new
    end
  end

  def self.for_event(event_type, quota_sid, point_in_time)
    event_class_for(event_type).select(:quota_definition_sid,
                                       :occurrence_timestamp,
                                       Sequel.as(event_type, 'event_type'))
                               .where(quota_definition_sid: quota_sid)
                               .where('occurrence_timestamp <= ?', point_in_time)
  end

  def self.event_class_for(event_type)
    Object.const_get("Quota#{event_type.capitalize}Event")
  rescue NameError => e
    raise ArgumentError, "Unknown event type: #{event_type}. #{e.message}"
  end
end
