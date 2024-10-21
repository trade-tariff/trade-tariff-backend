class CdsImporter
  class EntityMapper
    class QuotaSuspensionPeriodMapper < BaseMapper
      self.mapping_path = 'quotaSuspensionPeriod'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_class = 'QuotaSuspensionPeriod'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :quota_suspension_period_sid,
        'sid' => :quota_definition_sid,
        "#{mapping_path}.suspensionStartDate" => :suspension_start_date,
        "#{mapping_path}.suspensionEndDate" => :suspension_end_date,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
