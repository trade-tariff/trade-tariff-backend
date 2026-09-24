# frozen_string_literal: true

module SearchExport
  class DateRange < Data.define(:from, :to)
    MAX_DAYS = SearchAnalytics::DateRange::MAX_DAYS
    InvalidRange = Class.new(StandardError)

    def self.parse(from:, to:, now: Time.current)
      unless [from, to].all? { |value| value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/) }
        raise InvalidRange, 'Enter both From and To dates in YYYY-MM-DD format.'
      end

      first = Date.iso8601(from)
      last = Date.iso8601(to)
      raise InvalidRange, 'Enter valid calendar dates for From and To.' unless first.year.positive? && last.year.positive?
      raise InvalidRange, 'From must be on or before To.' if first > last
      raise InvalidRange, 'To must be today or earlier (UTC).' if last > now.utc.to_date
      raise InvalidRange, "Choose a range of no more than #{MAX_DAYS} days." if (last - first).to_i + 1 > MAX_DAYS

      new(from: first, to: last)
    rescue Date::Error
      raise InvalidRange, 'Enter valid calendar dates for From and To.'
    end
  end
end
