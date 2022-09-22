class CdsImporter
  class EntityMapper
    class QuotaOrderNumberOriginExclusionMapper < BaseMapper
      self.entity_class = 'QuotaOrderNumberOriginExclusion'.freeze

      self.mapping_root = 'QuotaOrderNumber'.freeze

      self.mapping_path = 'quotaOrderNumberOrigin.quotaOrderNumberOriginExclusion'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'quotaOrderNumberOrigin.sid' => :quota_order_number_origin_sid,
        "#{mapping_path}.geographicalArea.sid" => :excluded_geographical_area_sid,
      ).freeze

      self.primary_filters = {
        quota_order_number_origin_sid: :quota_order_number_origin_sid,
      }.freeze
    end
  end
end
