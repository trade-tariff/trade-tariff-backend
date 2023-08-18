class ExchangeRateFile < Sequel::Model
  def file_path
    "/api/v2/exchange_rates/files.#{format}?month=#{period_month}&year=#{period_year}"
  end

  def id
    "#{period_year}-#{period_month}-#{format}_file"
  end
end
