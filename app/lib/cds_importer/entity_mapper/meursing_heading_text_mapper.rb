#
# MeursingTablePlan -> meursingHeading -> meursingHeadingText
#

class CdsImporter
  class EntityMapper
    class MeursingHeadingTextMapper < BaseMapper
      self.entity_class = 'MeursingHeadingText'.freeze

      self.mapping_root = 'MeursingTablePlan'.freeze

      self.mapping_path = 'meursingHeading.meursingHeadingText'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'meursingTablePlanId' => :meursing_table_plan_id,
        'meursingHeading.meursingHeadingNumber' => :meursing_heading_number,
        'meursingHeading.rowColumnCode' => :row_column_code,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
