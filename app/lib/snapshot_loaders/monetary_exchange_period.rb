module SnapshotLoaders
  class MonetaryExchangePeriod < Base
    def self.load(file, batch)
      periods = []
      rates = []

      batch.each do |attributes|
        periods.push({
          monetary_exchange_period_sid: attributes.dig('MonetaryExchangePeriod', 'sid'),
          parent_monetary_unit_code: attributes.dig('MonetaryExchangePeriod', 'monetaryUnit', 'monetaryUnitCode'),
          validity_start_date: attributes.dig('MonetaryExchangePeriod', 'validityStartDate'),
          validity_end_date: attributes.dig('MonetaryExchangePeriod', 'validityEndDate'),
          operation: attributes.dig('MonetaryExchangePeriod', 'metainfo', 'opType'),
          operation_date: attributes.dig('MonetaryExchangePeriod', 'metainfo', 'transactionDate'),
          filename: file,
        })

        attributes['MonetaryExchangePeriod']['monetaryExchangeRate'].each do |rate|
          next unless rate.is_a?(Hash)

          rates.push({
            monetary_exchange_period_sid: attributes.dig('MonetaryExchangePeriod', 'sid'),
            child_monetary_unit_code: rate['childMonetaryUnitCode'],
            exchange_rate: rate['exchangeRate'],
            operation: rate.dig('metainfo', 'opType'),
            operation_date: rate.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('MonetaryExchangePeriod::Operation').multi_insert(periods)
      Object.const_get('MonetaryExchangeRate::Operation').multi_insert(rates)
    end
  end
end
