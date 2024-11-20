class CdsImporter
  class EntityMapper
    class QuotaBlockingPeriodMapper < BaseMapper
      self.entity_class = 'QuotaBlockingPeriod'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaBlockingPeriod'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.blockingStartDate" => :blocking_start_date,
        "#{mapping_path}.blockingEndDate" => :blocking_end_date,
        "#{mapping_path}.blockingPeriodType" => :blocking_period_type,
        "#{mapping_path}.description" => :description,
        "#{mapping_path}.quotaBlockingPeriodSid" => :quota_blocking_period_sid,
      ).freeze
    end
  end
end
