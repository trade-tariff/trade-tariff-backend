require 'net/http'
require 'json'

module BankHolidays
  def self.last(n)
    [weekends(n), holidays(n)].flatten.compact.uniq.sort.last(n)
  end

  private

  def self.weekends(n)
    ((Date.current - n + 1)..Date.current).to_a.select { |d| d.saturday? || d.sunday? }
  end

  def self.holidays(n)
    Holidays.between(Date.current - n, Date.current, :be_nl, :gb)
            .map { |h| h[:date] }
  end
end
