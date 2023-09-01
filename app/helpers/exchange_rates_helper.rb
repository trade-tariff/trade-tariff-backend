module ExchangeRatesHelper
  def next_month_year(date)
    if date.next_month.year != date.year
      date.next_month.year
    else
      date.year
    end
  end

  def next_month(date)
    date.next_month.month
  end
end
