require 'net/http'
require 'json'

module BankHolidays
  def self.last(days)
    [weekends(days), holidays(days)].flatten.compact.uniq.sort.last(days)
  end

  def self.weekends(days)
    ((Time.zone.today - days + 1)..Time.zone.today).to_a.select { |d| d.saturday? || d.sunday? }
  end

  def self.holidays(days)
    Holidays.between(Time.zone.today - days, Time.zone.today, :be_nl, :gb)
            .map { |h| h[:date] }
  end
end
