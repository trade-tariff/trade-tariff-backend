class CdsImporter
  class EntityMapper
    class QuotaUnsuspensionEventMapper < BaseMapper
      self.entity_class = 'QuotaUnsuspensionEvent'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaUnsuspensionEvent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.unsuspensionDate" => :unsuspension_date,
      ).freeze
    end
  end
end
