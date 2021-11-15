class CdsImporter
  class EntityMapper
    class CertificateTypeMapper < BaseMapper
      self.entity_class = 'CertificateType'.freeze

      self.mapping_root = 'CertificateType'.freeze

      self.entity_mapping = base_mapping.merge(
        'certificateTypeCode' => :certificate_type_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
