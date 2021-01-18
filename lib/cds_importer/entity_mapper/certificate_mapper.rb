class CdsImporter
  class EntityMapper
    class CertificateMapper < BaseMapper
      self.entity_class = 'Certificate'.freeze

      self.mapping_root = 'Certificate'.freeze

      self.entity_mapping = base_mapping.merge(
        'certificateType.certificateTypeCode' => :certificate_type_code,
        'certificateCode' => :certificate_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
