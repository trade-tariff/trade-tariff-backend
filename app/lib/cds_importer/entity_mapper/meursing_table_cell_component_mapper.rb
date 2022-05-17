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
        "#{mapping_path}.meursingSubheading.subheadingSequenceNumber" => :subheading_sequence_number,
      ).freeze
    end
  end
end
