class CdsImporter
  class EntityMapper
    class MeursingTableCellComponentMapper < BaseMapper
      self.entity_class = 'MeursingTableCellComponent'.freeze

      self.mapping_root = 'MeursingAdditionalCode'.freeze

      self.mapping_path = 'meursingCellComponent'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :meursing_additional_code_sid,
        'additionalCodeCode' => :additional_code,
        "#{mapping_path}.meursingSubheading.meursingHeading.meursingTablePlan.meursingTablePlanId" => :meursing_table_plan_id,
        "#{mapping_path}.meursingSubheading.meursingHeading.meursingHeadingNumber" => :heading_number,
        "#{mapping_path}.meursingSubheading.meursingHeading.rowColumnCode" => :row_column_code,
        "#{mapping_path}.meursingSubheading.subheadingSequenceNumber" => :subheading_sequence_number
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
