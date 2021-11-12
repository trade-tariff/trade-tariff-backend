#
# QuotaCriticalEvent is nested in to QuotaDefinition.
#

class CdsImporter
  class EntityMapper
    class QuotaCriticalEventMapper < BaseMapper
      self.entity_class = 'QuotaCriticalEvent'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaCriticalEvent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.criticalState" => :critical_state,
        "#{mapping_path}.criticalStateChangeDate" => :critical_state_change_date
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
