require 'date'

module TimeMachine
  def self.no_time_machine
    previous = TradeTariffRequest.time_machine_now

    raise ArgumentError, 'requires a block' unless block_given?

    TradeTariffRequest.time_machine_now = nil

    yield
  ensure
    TradeTariffRequest.time_machine_now = previous
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

    previous = TradeTariffRequest.time_machine_now
    raise ArgumentError, 'requires a block' unless block_given?

    TradeTariffRequest.time_machine_now = datetime
    yield
  ensure
    TradeTariffRequest.time_machine_now = previous
  end

  def self.now(&block)
    at(Time.current, &block)
  end

  def self.with_relevant_validity_periods
    raise ArgumentError, 'requires a block' unless block_given?

    TradeTariffRequest.time_machine_relevant = true
    yield
  ensure
    TradeTariffRequest.time_machine_relevant = nil
  end

  def self.date_is_set?
    !point_in_time.nil?
  end

  def self.point_in_time
    TradeTariffRequest.time_machine_now
  end
end
