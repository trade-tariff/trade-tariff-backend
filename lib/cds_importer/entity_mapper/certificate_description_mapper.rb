#
# There is no collection with CertificateDescriptions in new xml.
# CertificateDescription is nested in to CertificateDescriptionPeriod,
# and certificateDescriptionPeriod is nested in to Certificate xml object.
# also CertificateDescription has attributes which are not present in CertificateDescription xml object
# e.g. 'certificate_description_period_sid' - present in parent object
# So we will pass @values for CertificateDescription the same as for Certificate.
#

class CdsImporter
  class EntityMapper
    class CertificateDescriptionMapper < BaseMapper
      self.entity_class = 'CertificateDescription'.freeze

      self.mapping_root = 'Certificate'.freeze

      self.mapping_path = 'certificateDescriptionPeriod.certificateDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'certificateDescriptionPeriod.sid' => :certificate_description_period_sid,
        "#{mapping_path}.language.languageId" => :language_id,
        'certificateType.certificateTypeCode' => :certificate_type_code,
        'certificateCode' => :certificate_code,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
