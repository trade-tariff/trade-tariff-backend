class ExchangeRateFile < Sequel::Model
  APPLICABLE_TYPES = %w[monthly_csv monthly_xml spot_csv average_csv].freeze
  OBJECT_KEY_PREFIX = 'data/exchange_rates'.freeze

  include ContentAddressableId

  TYPE_TO_FILE_MAP = {
    ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE => %w[monthly_csv monthly_xml],
    ExchangeRateCurrencyRate::SPOT_RATE_TYPE => %w[spot_csv],
    ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE => %w[average_csv],
  }.freeze

  content_addressable_fields :format, :type, :publication_date, :period_year, :period_month

  def file_path
    "/api/v2/exchange_rates/files/#{filename}"
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

    def by_year(period_year)
      where(period_year:)
    end

    def by_rate_type(rate_type)
      where(type: TYPE_TO_FILE_MAP[rate_type])
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

    def filename_for_download(type, format, year, month)
      # `to_i` is vital, since a number starting with 0 is interpreted as octal.
      month_with_zero = sprintf('%02i', month.to_i(10))

      case type
      when 'monthly_csv_hmrc'
        "#{year}#{month_with_zero}MonthlyRates.#{format}"
      when 'monthly_csv', 'monthly_xml'
        "exrates-monthly-#{month_with_zero}#{year[2..3]}.#{format}"
      else
        filename_for(type, format, year, month)
      end
    end

    def applicable_files_for(month, year, rate_type)
      file_types = TYPE_TO_FILE_MAP[rate_type]

      where(period_year: year, period_month: month, type: file_types)
        .all
    end

    def all_years(rate_type)
      distinct
        .by_rate_type(rate_type)
        .select(:period_year)
        .order(Sequel.desc(:period_year))
        .select_map(:period_year)
    end

    def months_for(type, year)
      scope = by_rate_type(type)
        .order(Sequel.desc(:period_year), Sequel.desc(:period_month))
        .select(:period_year, :period_month)
        .distinct

      scope = if year.present?
                scope.by_year(year)
              else
                scope
              end

      scope.pluck(:period_month, :period_year)
    end
  end
end
