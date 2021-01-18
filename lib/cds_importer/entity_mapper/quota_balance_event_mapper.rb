#
# QuotaBalanceEvent is nested in to QuotaDefinition.
#

class CdsImporter
  class EntityMapper
    class QuotaBalanceEventMapper < BaseMapper
      self.entity_class = 'QuotaBalanceEvent'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaBalanceEvent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.lastImportDateInAllocation" => :last_import_date_in_allocation,
        "#{mapping_path}.oldBalance" => :old_balance,
        "#{mapping_path}.newBalance" => :new_balance,
        "#{mapping_path}.importedAmount" => :imported_amount
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
