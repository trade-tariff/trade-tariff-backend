class CdsImporter
  class EntityMapper
    class QuotaClosedAndTransferredEventMapper < BaseMapper
      self.entity_class = 'QuotaClosedAndTransferredEvent'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaClosedAndTransferredEvent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        "#{mapping_path}.occurrenceTimestamp" => :occurrence_timestamp,
        "#{mapping_path}.closingDate" => :closing_date,
        "#{mapping_path}.targetQuotaDefinition.sid" => :target_quota_definition_sid,
        "#{mapping_path}.transferredAmount" => :transferred_amount,
      ).freeze

      before_oplog_inserts do |_xml_node, _mapper, model_instance, expanded_attributes|
        current_definition_start_date = expanded_attributes['validityStartDate']
        target_definition_start_date = expanded_attributes.dig(mapping_path, 'targetQuotaDefinition', 'validityStartDate')

        model_instance.skip_import! if current_definition_start_date >= target_definition_start_date
      end
    end
  end
end
