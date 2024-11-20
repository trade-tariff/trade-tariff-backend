class CdsImporter
  class EntityMapper
    class CertificateMapper < BaseMapper
      self.entity_class = 'Certificate'.freeze

      self.mapping_root = 'Certificate'.freeze

      self.entity_mapping = base_mapping.merge(
        'certificateType.certificateTypeCode' => :certificate_type_code,
        'certificateCode' => :certificate_code,
      ).freeze
    end
  end
end
