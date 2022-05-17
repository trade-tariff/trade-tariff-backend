class CdsImporter
  class EntityMapper
    class CertificateTypeMapper < BaseMapper
      self.entity_class = 'CertificateType'.freeze

      self.mapping_root = 'CertificateType'.freeze

      self.entity_mapping = base_mapping.merge(
        'certificateTypeCode' => :certificate_type_code,
      ).freeze
    end
  end
end
