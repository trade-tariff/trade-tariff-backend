#
# CertificateDescriptionPeriod has attributes which are not present in CertificateDescriptionPeriod xml object
# e.g. 'certificate_type_code' - present in parent object
# So we will pass @values CertificateDescriptionPeriod the same as for Certificate
#

class CdsImporter
  class EntityMapper
    class CertificateDescriptionPeriodMapper < BaseMapper
      self.entity_class = 'CertificateDescriptionPeriod'.freeze

      self.mapping_root = 'Certificate'.freeze

      self.mapping_path = 'certificateDescriptionPeriod'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :certificate_description_period_sid,
        'certificateType.certificateTypeCode' => :certificate_type_code,
        'certificateCode' => :certificate_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
