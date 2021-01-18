class CdsImporter
  class EntityMapper
    class MeursingAdditionalCodeMapper < BaseMapper
      self.entity_class = 'MeursingAdditionalCode'.freeze

      self.mapping_root = 'MeursingAdditionalCode'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :meursing_additional_code_sid,
        'additionalCodeCode' => :additional_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
