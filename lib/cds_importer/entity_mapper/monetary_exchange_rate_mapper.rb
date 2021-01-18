#
# MonetaryExchangeRate is nested in to MonetaryExchangePeriod.
#

class CdsImporter
  class EntityMapper
    class MonetaryExchangeRateMapper < BaseMapper
      self.entity_class = 'MonetaryExchangeRate'.freeze

      self.mapping_root = 'MonetaryExchangePeriod'.freeze

      self.mapping_path = 'monetaryExchangeRate'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :monetary_exchange_period_sid,
        "#{mapping_path}.childMonetaryUnitCode" => :child_monetary_unit_code,
        "#{mapping_path}.exchangeRate" => :exchange_rate
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
