class CdsImporter
  class EntityMapper
    class QuotaOrderNumberMapper < BaseMapper
      self.entity_class = 'QuotaOrderNumber'.freeze

      self.mapping_root = 'QuotaOrderNumber'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_order_number_sid,
        'quotaOrderNumberId' => :quota_order_number_id,
      ).freeze

      self.reportable_entity_mapping = reportable_base_mapping.merge(
        'sid' => :quota_order_number_sid,
        'quotaOrderNumberId' => :quota_order_number_id,
      ).freeze
    end
  end
end
