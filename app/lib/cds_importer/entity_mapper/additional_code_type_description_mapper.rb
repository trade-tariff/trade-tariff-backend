class CdsImporter
  class EntityMapper
    class AdditionalCodeTypeDescriptionMapper < BaseMapper
      self.entity_class = 'AdditionalCodeTypeDescription'.freeze

      self.mapping_root = 'AdditionalCodeType'.freeze

      self.mapping_path = 'additionalCodeTypeDescription'.freeze

      self.exclude_mapping = %w[validityStartDate validityEndDate].freeze

      self.entity_mapping = base_mapping.merge(
        'additionalCodeTypeId' => :additional_code_type_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
