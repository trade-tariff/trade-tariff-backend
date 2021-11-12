#
# QuotaAssociation is nested in to QuotaDefinition.
# So we will pass @values for QuotaAssociation the same as for QuotaDefinition.
#

class CdsImporter
  class EntityMapper
    class QuotaAssociationMapper < BaseMapper
      self.entity_class = 'QuotaAssociation'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.mapping_path = 'quotaAssociation'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :main_quota_definition_sid,
        "#{mapping_path}.subQuotaDefinition.sid" => :sub_quota_definition_sid,
        "#{mapping_path}.relationType" => :relation_type,
        "#{mapping_path}.coefficient" => :coefficient
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
