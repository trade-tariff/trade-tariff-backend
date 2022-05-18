class CdsImporter
  class EntityMapper
    class MeursingTablePlanMapper < BaseMapper
      self.entity_class = 'MeursingTablePlan'.freeze

      self.mapping_root = 'MeursingTablePlan'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'meursingTablePlanId' => :meursing_table_plan_id,
      ).freeze
    end
  end
end
