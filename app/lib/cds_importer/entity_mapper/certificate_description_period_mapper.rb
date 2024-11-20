class CdsImporter
  class EntityMapper
    class CertificateDescriptionPeriodMapper < BaseMapper
      self.entity_class = 'CertificateDescriptionPeriod'.freeze

      self.mapping_root = 'Certificate'.freeze

      self.mapping_path = 'certificateDescriptionPeriod'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :certificate_description_period_sid,
        'certificateType.certificateTypeCode' => :certificate_type_code,
        'certificateCode' => :certificate_code,
      ).freeze
    end
  end
end
