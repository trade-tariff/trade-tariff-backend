class CdsImporter
  class EntityMapper
    class QuotaUnblockingEventMapper < BaseMapper
      self.entity_class = 'QuotaUnblockingEvent'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaUnblockingEvent'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.unblockingDate" => :unblocking_date,
      ).freeze

      self.primary_filters = {
        quota_definition_sid: :quota_definition_sid,
      }.freeze
    end
  end
end
