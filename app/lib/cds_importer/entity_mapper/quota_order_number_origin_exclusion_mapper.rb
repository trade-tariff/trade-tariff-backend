#
# QuotaOrderNumberOriginExclusion is nested in to QuotaOrderNumberOrigin.
# QuotaOrderNumberOrigin is nested in to QuotaOrderNumber.
#

class CdsImporter
  class EntityMapper
    class QuotaOrderNumberOriginExclusionMapper < BaseMapper
      self.entity_class = 'QuotaOrderNumberOriginExclusion'.freeze

      self.mapping_root = 'QuotaOrderNumber'.freeze

      self.mapping_path = 'quotaOrderNumberOrigin.quotaOrderNumberOriginExclusions'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'quotaOrderNumberOrigin.sid' => :quota_order_number_origin_sid,
        "#{mapping_path}.geographicalArea.sid" => :excluded_geographical_area_sid,
      ).freeze
    end
  end
end
