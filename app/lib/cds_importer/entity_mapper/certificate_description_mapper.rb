class CdsImporter
  class EntityMapper
    class CertificateDescriptionMapper < BaseMapper
      self.entity_class = 'CertificateDescription'.freeze

      self.mapping_root = 'Certificate'.freeze

      self.mapping_path = 'certificateDescriptionPeriod.certificateDescription'.freeze

      self.exclude_mapping = %w[validityStartDate validityEndDate].freeze

      self.entity_mapping = base_mapping.merge(
        'certificateDescriptionPeriod.sid' => :certificate_description_period_sid,
        "#{mapping_path}.language.languageId" => :language_id,
        'certificateType.certificateTypeCode' => :certificate_type_code,
        'certificateCode' => :certificate_code,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
