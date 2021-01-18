#
# QuotaReopeningEvent is nested in to QuotaDefinition.
#

class CdsImporter
  class EntityMapper
    class QuotaReopeningEventMapper < BaseMapper
      self.entity_class = 'QuotaReopeningEvent'.freeze

      self.mapping_path = 'quotaReopeningEvent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.reopeningDate" => :reopening_date
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
