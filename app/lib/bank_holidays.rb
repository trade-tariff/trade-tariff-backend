require 'net/http'
require 'json'

module BankHolidays
  def self.last(n)
    [weekends(n), holidays(n)].flatten.compact.uniq.sort.last(n)
  end

  private

  def self.weekends(n)
    ((Time.zone.today - n + 1)..Time.zone.today).to_a.select { |d| d.saturday? || d.sunday? }
  end

  def self.holidays(n)
    Holidays.between(Time.zone.today - n, Time.zone.today, :be_nl, :gb)
            .map { |h| h[:date] }
  end
end
