#
# MeursingTablePlan -> meursingHeading -> meursingSubheading
#

class CdsImporter
  class EntityMapper
    class MeursingSubheadingMapper < BaseMapper
      self.entity_class = 'MeursingSubheading'.freeze

      self.mapping_root = 'MeursingTablePlan'.freeze

      self.mapping_path = 'meursingHeading.meursingSubheading'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'meursingTablePlanId' => :meursing_table_plan_id,
        'meursingHeading.meursingHeadingNumber' => :meursing_heading_number,
        'meursingHeading.rowColumnCode' => :row_column_code,
        "#{mapping_path}.subheadingSequenceNumber" => :subheading_sequence_number,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
