class ExchangeRateFile < Sequel::Model
  APPLICABLE_TYPES = %w[monthly_csv monthly_xml].freeze
  OBJECT_KEY_PREFIX = 'data/exchange_rates'.freeze

  def file_path
    "/api/v2/exchange_rates/files.#{format}?month=#{period_month}&year=#{period_year}"
  end

  def id
    "#{period_year}-#{period_month}-#{format}_file"
  end

  dataset_module do
    def applicable_types
      where(type: APPLICABLE_TYPES)
    end
  end

  class << self
    def filepath_for(type, format, year, month)
      object_key_prefix = "#{OBJECT_KEY_PREFIX}/#{year}/#{month}/"
      filename = filename_for(type, format, year, month)

      "#{object_key_prefix}#{filename}"
    end

    def filename_for(type, format, year, month)
      "#{type}_#{year}-#{month}.#{format}"
    end

    def applicable_files_for(month, year)
      applicable_types
        .where(period_year: year, period_month: month)
        .all
    end
  end
end
