class ExchangeRateFile < Sequel::Model
  def file_path
    "/api/v2/exchange_rates/files.#{format}?month=#{period_month}&year=#{period_year}"
  end

  def id
    "#{period_year}-#{period_month}-#{format}-exchange_rate_file"
  end

  class << self
    def wrap(files)
      files.map do |file|
        build(file)
      end
    end

    def build(file)
      exchange_rate_file = new
      exchange_rate_file.file_path = file.file_path
      exchange_rate_file.file_size = file.file_size
      exchange_rate_file.format = file.format
      exchange_rate_file
    end
  end
end
