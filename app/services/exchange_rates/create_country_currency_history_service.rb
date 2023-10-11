module ExchangeRates
  class CreateCountryCurrencyHistoryService
    delegate :client, to: :class

    HOST = 'http://www.hmrc.gov.uk'.freeze
    YEARS = %w[
      21
      22
      23
    ].freeze
    MONTHS = 1..12

    def call
      ExchangeRateCountryCurrency.truncate
      ExchangeRateCurrencyRate.by_type('monthly').delete

      YEARS.each do |year|
        MONTHS.each do |month|
          month = month.to_s.rjust(2, '0')
          path = "/softwaredevelopers/rates/exrates-monthly-#{month}#{year}.XML"
          Rails.logger.info("Getting #{path}")
          response = client.get(path)

          unless response.status == 200
            Rails.logger.error("Failed to get #{path}")
            next
          end

          xml = Nokogiri::XML(response.body)

          period = xml.xpath('//exchangeRateMonthList').attr('Period').value.split(' to ')
          period_start_date = Date.parse(period.first)
          period_end_date = Date.parse(period.last)
          database_country_currencies = country_currencies_for(period_start_date, period_end_date)
          xml_country_currencies = xml_country_currencies_for(xml)

          removed, added, changed = enumerate_changes(database_country_currencies, xml_country_currencies)
          if removed.any?
            Rails.logger.info("Removing #{removed.length} country currencies #{removed}")
          end
          if added.any?
            Rails.logger.info("Adding #{added.length} country currencies #{added}")
          end
          if changed.any?
            Rails.logger.info("Changing #{changed.length} country currencies #{changed}")
          end

          File.write("#{year}#{month}.json", JSON.pretty_generate(removed:, added:, changed:))

          if removed.any?
            removed.each do |country_code, currency_code|
              validity_end_date = period_start_date - 1.day

              database_country_currencies[[country_code, currency_code]].each do |country_currency|
                country_currency.validity_end_date = validity_end_date
                country_currency.save
              end
            end
          end

          inserted = Set.new

          xml.xpath('//exchangeRateMonthList/exchangeRate').each do |exchange_rate|
            country_code = exchange_rate.xpath('countryCode').text.strip
            currency_code = exchange_rate.xpath('currencyCode').text.strip

            unless inserted.include?(currency_code)
              ExchangeRateCurrencyRate.create(
                currency_code:,
                rate: exchange_rate.xpath('rateNew').text.strip,
                validity_start_date: period_start_date,
                validity_end_date: period_end_date,
                rate_type: ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE,
              )
              inserted << currency_code
            end

            next unless added.include?([country_code, currency_code]) || changed.include?([country_code, currency_code])

            validity_start_date = period_start_date
            validity_end_date = nil

            ExchangeRateCountryCurrency.create(
              country_code:,
              currency_code:,
              country_description: exchange_rate.xpath('countryName').text.strip,
              currency_description: exchange_rate.xpath('currencyName').text.strip,
              validity_start_date:,
              validity_end_date:,
            )
          end
        end
      end
    end

    def country_currencies_for(period_start_date, period_end_date)
      ExchangeRateCountryCurrency
        .between(period_start_date, period_end_date)
        .all
        .group_by { |rate| [rate.country_code, rate.currency_code] }
    end

    def xml_country_currencies_for(xml)
      xml.xpath('//exchangeRateMonthList/exchangeRate').index_by do |exchange_rate|
        [
          exchange_rate.xpath('countryCode').text.strip,
          exchange_rate.xpath('currencyCode').text.strip,
        ]
      end
    end

    def enumerate_changes(database_country_currencies, xml_country_currencies)
      removed = database_country_currencies.keys - xml_country_currencies.keys # all get end dated
      added = xml_country_currencies.keys - database_country_currencies.keys # all get created
      changed = (database_country_currencies.keys & xml_country_currencies.keys).each_with_object([]) do |(country_code, currency_code), acc|
        previous_country_currency = database_country_currencies[[country_code, currency_code]].max_by(&:validity_start_date).dup
        next_country_currency = xml_country_currencies[[country_code, currency_code]]

        previous_country_currency.country_description = next_country_currency.xpath('countryName').text.strip
        previous_country_currency.currency_description = next_country_currency.xpath('currencyName').text.strip

        if previous_country_currency.changed_columns.any?
          acc << [country_code, currency_code]
        end
      end

      [removed, added, changed]
    end

    def self.client
      Faraday.new(url: HOST)
    end
  end
end
