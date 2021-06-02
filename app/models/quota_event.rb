class QuotaEvent
  EVENTS = %w[exhaustion balance critical reopening unblocking unsuspension].freeze

  # Generate SELECT .. UNION from all event types
  def self.for_quota_definition(quota_sid, point_in_time)
    EVENTS.from(1).inject(for_event(EVENTS.first, quota_sid, point_in_time)) { |memo, event_type|
      memo.union(for_event(event_type, quota_sid, point_in_time), from_self: true)
    }.order(Sequel.desc(:occurrence_timestamp), Sequel.desc(:event_type))
  end

  def self.last_for(quota_sid, point_in_time)
    event = for_quota_definition(quota_sid, point_in_time).first

    if event.present?
      Object.const_get("Quota#{event[:event_type].capitalize}Event")
    else
      NullObject.new
    end
  end

  def self.for_event(event_type, quota_sid, point_in_time)
    Object.const_get("Quota#{event_type.capitalize}Event").select(:quota_definition_sid,
                                                                  :occurrence_timestamp,
                                                                  Sequel.as(event_type, 'event_type'))
                                                          .where(quota_definition_sid: quota_sid)
                                                          .where('occurrence_timestamp <= ?', point_in_time)
  end
end
