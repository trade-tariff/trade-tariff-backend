class CdsImporter
  class EntityMapper
    class MonetaryUnitMapper < BaseMapper
      self.entity_class = 'MonetaryUnit'.freeze

      self.mapping_root = 'MonetaryUnit'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'monetaryUnitCode' => :monetary_unit_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
