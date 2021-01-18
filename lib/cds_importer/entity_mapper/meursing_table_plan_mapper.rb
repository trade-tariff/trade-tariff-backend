class CdsImporter
  class EntityMapper
    class MeursingTablePlanMapper < BaseMapper
      self.entity_class = 'MeursingTablePlan'.freeze

      self.mapping_root = 'MeursingTablePlan'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'meursingTablePlanId' => :meursing_table_plan_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
