#
# MeursingTablePlan -> meursingHeading
#

class CdsImporter
  class EntityMapper
    class MeursingHeadingMapper < BaseMapper
      self.entity_class = 'MeursingHeading'.freeze

      self.mapping_root = 'MeursingTablePlan'.freeze

      self.mapping_path = 'meursingHeading'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'meursingTablePlanId' => :meursing_table_plan_id,
        "#{mapping_path}.meursingHeadingNumber" => :meursing_heading_number,
        "#{mapping_path}.rowColumnCode" => :row_column_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
