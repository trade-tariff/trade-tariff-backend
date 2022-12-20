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

      before_oplog_inserts do |xml_node, _mapper, model_instance|
        transfer_node = if xml_node[mapping_path].is_a?(Array)
                          xml_node[mapping_path].find { |transfer_node| xml_node_equivalent_to_model_instance?(model_instance, transfer_node) }
                        else
                          xml_node[mapping_path]
                        end

        current_definition_start_date = xml_node['validityStartDate']
        target_definition_start_date = transfer_node.dig('targetQuotaDefinition', 'validityStartDate')

        model_instance.skip_import! if current_definition_start_date >= target_definition_start_date
      end

      def self.xml_node_equivalent_to_model_instance?(model_instance, xml_node)
        model_instance.transferred_amount.to_s == xml_node['transferredAmount'] &&
          xml_node['closingDate'].to_s.include?(model_instance.closing_date.iso8601) &&
          model_instance.occurrence_timestamp.iso8601.include?(xml_node['occurrenceTimestamp']) &&
          model_instance.target_quota_definition_sid.to_s == xml_node['targetQuotaDefinition']['sid']
      end
    end
  end
end
