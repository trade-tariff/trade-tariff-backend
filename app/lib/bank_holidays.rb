require 'net/http'
require 'json'

module BankHolidays
  def self.last(days)
    [weekends(days), holidays(days)].flatten.compact.uniq.sort.last(days)
  end

  def self.weekends(_days)
    ((Time.zone.today - n + 1)..Time.zone.today).to_a.select { |d| d.saturday? || d.sunday? }
  end

  def self.holidays(_days)
    Holidays.between(Time.zone.today - n, Time.zone.today, :be_nl, :gb)
            .map { |h| h[:date] }
  end
end
