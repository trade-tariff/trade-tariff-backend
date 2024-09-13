class CdsImporter
  class EntityMapper
    class QuotaOrderNumberOriginMapper < BaseMapper
      self.entity_class = 'QuotaOrderNumberOrigin'.freeze

      self.mapping_root = 'QuotaOrderNumber'.freeze

      self.mapping_path = 'quotaOrderNumberOrigin'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :quota_order_number_origin_sid,
        'sid' => :quota_order_number_sid,
        "#{mapping_path}.geographicalArea.geographicalAreaId" => :geographical_area_id,
        "#{mapping_path}.geographicalArea.sid" => :geographical_area_sid,
      ).freeze
    end
  end
end
