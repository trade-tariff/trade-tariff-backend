module ExchangeRates
  class ExchangeRateFile
    attr_accessor :file_path, :file_size, :format, :period_year, :period_month, :publication_date

    def id
      "#{period_year}-#{period_month}-#{format}_file"
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
end
