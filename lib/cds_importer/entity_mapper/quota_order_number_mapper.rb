class CdsImporter
  class EntityMapper
    class QuotaOrderNumberMapper < BaseMapper
      self.entity_class = 'QuotaOrderNumber'.freeze

      self.mapping_root = 'QuotaOrderNumber'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_order_number_sid,
        'quotaOrderNumberId' => :quota_order_number_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
