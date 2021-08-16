module TimeMachine
  THREAD_DATETIME_KEY = :time_machine_now
  THREAD_RELEVANT_KEY = :time_machine_relevant

  # Travel to specified date and time
  def self.at(datetime)
    datetime = Time.zone.now if datetime.blank?
    datetime = begin
      Time.zone.parse(datetime.to_s)
    rescue ArgumentError
      Time.zone.now
    end
    datetime = Time.zone.now if datetime.blank?

    previous = Thread.current[THREAD_DATETIME_KEY]
    raise ArgumentError, 'requires a block' unless block_given?

    Thread.current[THREAD_DATETIME_KEY] = datetime
    yield
  ensure
    Thread.current[THREAD_DATETIME_KEY] = previous
  end

  def self.now(&block)
    at(Time.zone.now, &block)
  end

  def self.with_relevant_validity_periods
    raise ArgumentError, 'requires a block' unless block_given?

    Thread.current[THREAD_RELEVANT_KEY] = true
    yield
  ensure
    Thread.current[THREAD_RELEVANT_KEY] = nil
  end
end
