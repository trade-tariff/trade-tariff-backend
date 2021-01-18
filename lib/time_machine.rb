require 'date'

module TimeMachine
  THREAD_DATETIME_KEY = :time_machine_now
  THREAD_RELEVANT_KEY = :time_machine_relevant

  # Travel to specified date and time
  def self.at(datetime, &block)
      datetime = DateTime.current if datetime.blank?
      datetime = begin
                   DateTime.parse(datetime.to_s)
                 rescue ArgumentError
                   DateTime.current
                  end

      previous = Thread.current[THREAD_DATETIME_KEY]
      raise ArgumentError, 'requires a block' unless block_given?
      Thread.current[THREAD_DATETIME_KEY] = datetime
      yield
    ensure
      Thread.current[THREAD_DATETIME_KEY] = previous
  end

  def self.now(&block)
    at(DateTime.current, &block)
  end

  def self.with_relevant_validity_periods(&block)
    raise ArgumentError, 'requires a block' unless block_given?
    Thread.current[THREAD_RELEVANT_KEY] = true
    yield
  ensure
    Thread.current[THREAD_RELEVANT_KEY] = nil
  end
end
