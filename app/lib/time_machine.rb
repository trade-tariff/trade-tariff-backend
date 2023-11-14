require 'date'

module TimeMachine
  THREAD_DATETIME_KEY = :time_machine_now
  THREAD_RELEVANT_KEY = :time_machine_relevant

  def self.no_time_machine
    previous = Thread.current[THREAD_DATETIME_KEY]

    raise ArgumentError, 'requires a block' unless block_given?

    Thread.current[THREAD_DATETIME_KEY] = nil

    yield
  ensure
    Thread.current[THREAD_DATETIME_KEY] = previous
  end

  # Travel to specified date and time
  def self.at(datetime)
    datetime = Time.current if datetime.blank?
    datetime = begin
      # rubocop:disable Style/DateTime
      DateTime.parse(datetime.to_s)
      # rubocop:enable Style/DateTime
    rescue ArgumentError
      Time.current
    end

    previous = Thread.current[THREAD_DATETIME_KEY]
    raise ArgumentError, 'requires a block' unless block_given?

    Thread.current[THREAD_DATETIME_KEY] = datetime
    yield
  ensure
    Thread.current[THREAD_DATETIME_KEY] = previous
  end

  def self.now(&block)
    at(Time.current, &block)
  end

  def self.with_relevant_validity_periods
    raise ArgumentError, 'requires a block' unless block_given?

    Thread.current[THREAD_RELEVANT_KEY] = true
    yield
  ensure
    Thread.current[THREAD_RELEVANT_KEY] = nil
  end

  def self.date_is_set?
    !point_in_time.nil?
  end

  def self.point_in_time
    Thread.current[THREAD_DATETIME_KEY]
  end
end
