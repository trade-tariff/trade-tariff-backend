class CdsImporter
  class EntityMapper
    class MonetaryExchangePeriodMapper < BaseMapper
      self.entity_class = 'MonetaryExchangePeriod'.freeze

      self.mapping_root = 'MonetaryExchangePeriod'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :monetary_exchange_period_sid,
        'monetaryUnit.monetaryUnitCode' => :parent_monetary_unit_code,
      ).freeze
    end
  end
end
