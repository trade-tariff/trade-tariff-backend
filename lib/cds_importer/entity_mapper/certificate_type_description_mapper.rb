#
# CertificateTypeDescription is nested in to CertificateType
# CertificateTypeDescription has attributes which are not present in CertificateTypeDescription xml object
# e.g. 'certificate_type_code' - present in parent object
# So we will pass @values for CertificateTypeDescription the same as for CertificateType.
#

class CdsImporter
  class EntityMapper
    class CertificateTypeDescriptionMapper < BaseMapper
      self.entity_class = 'CertificateTypeDescription'.freeze

      self.mapping_root = 'CertificateType'.freeze

      self.mapping_path = 'certificateTypeDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'certificateTypeCode' => :certificate_type_code,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
