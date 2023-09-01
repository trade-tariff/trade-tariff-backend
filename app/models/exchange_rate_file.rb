class ExchangeRateFile < Sequel::Model
  APPLICABLE_TYPES = %w[monthly_csv monthly_xml].freeze
  OBJECT_KEY_PREFIX = 'data/exchange_rates'.freeze

  include ContentAddressableId

  content_addressable_fields :format, :type, :publication_date, :period_year, :period_month

  def file_path
    "/api/v2/exchange_rates/files/#{type}_#{period_year}-#{period_month}.#{format}"
  end

  def object_key
    "#{OBJECT_KEY_PREFIX}/#{period_year}/#{period_month}/#{filename}"
  end

  def filename
    "#{type}_#{period_year}-#{period_month}.#{format}"
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
