module SearchDiagnostics
  class TimeWindow < Data.define(:start_time, :end_time)
    InvalidWindow = Class.new(ArgumentError)

    DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
    MAX_CUSTOM_DAYS = 31
    LOG_RETENTION_DAYS = 90

    def self.resolve(lookback_hours: nil, from: nil, to: nil, now: Time.current)
      return custom(from:, to:, now:) if from.present? || to.present?

      lookback(lookback_hours, now:)
    end

    def self.lookback(value, now:)
      hours = if value.blank?
                RequestLogLookup::DEFAULT_LOOKBACK_HOURS
              else
                Integer(value).clamp(1, RequestLogLookup::MAX_LOOKBACK_HOURS)
              end

      new(start_time: now - hours.hours, end_time: now)
    rescue ArgumentError, TypeError
      new(start_time: now - RequestLogLookup::DEFAULT_LOOKBACK_HOURS.hours, end_time: now)
    end

    def self.custom(from:, to:, now:)
      unless [from, to].all? { |value| value.is_a?(String) && value.match?(DATE_FORMAT) }
        raise InvalidWindow, 'Enter both From and To dates in YYYY-MM-DD format.'
      end

      first = Date.iso8601(from)
      last = Date.iso8601(to)
      today = now.utc.to_date

      raise InvalidWindow, 'From must be on or before To.' if first > last
      raise InvalidWindow, 'To must be today or earlier (UTC).' if last > today
      raise InvalidWindow, "From must be within the last #{LOG_RETENTION_DAYS} days." if first < today - LOG_RETENTION_DAYS
      raise InvalidWindow, "Choose a range of no more than #{MAX_CUSTOM_DAYS} days." if (last - first).to_i + 1 > MAX_CUSTOM_DAYS

      new(
        start_time: first.in_time_zone('UTC').beginning_of_day,
        end_time: [last.in_time_zone('UTC').end_of_day, now].min,
      )
    rescue Date::Error
      raise InvalidWindow, 'Enter valid calendar dates for From and To.'
    end
  end
end
