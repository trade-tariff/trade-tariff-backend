module BankHolidays
  def self.last(number_of_days)
    [weekends(number_of_days), holidays(number_of_days)].flatten.compact.uniq.sort.last(number_of_days)
  end

  def self.weekends(number_of_days)
    ((Date.current - number_of_days + 1)..Date.current).to_a.select { |d| d.saturday? || d.sunday? }
  end

  def self.holidays(number_of_days)
    Holidays.between(Date.current - number_of_days, Date.current, :be_nl, :gb)
            .map { |h| h[:date] }
  end
end
