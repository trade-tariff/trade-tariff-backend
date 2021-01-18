#
# QuotaExhaustionEvent is nested in to QuotaDefinition.
#

class CdsImporter
  class EntityMapper
    class QuotaExhaustionEventMapper < BaseMapper
      self.entity_class = 'QuotaExhaustionEvent'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaExhaustionEvent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.exhaustionDate" => :exhaustion_date
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
