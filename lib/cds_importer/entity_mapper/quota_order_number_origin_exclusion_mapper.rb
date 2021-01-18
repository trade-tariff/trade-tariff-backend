#
# QuotaOrderNumberOriginExclusion is nested in to QuotaOrderNumberOrigin.
# QuotaOrderNumberOrigin is nested in to QuotaOrderNumber.
#

class CdsImporter
  class EntityMapper
    class QuotaOrderNumberOriginExclusionMapper < BaseMapper
      self.entity_class = 'QuotaOrderNumberOriginExclusion'.freeze

      self.mapping_root = 'QuotaOrderNumber'.freeze

      self.mapping_path = 'quotaOrderNumberOrigin.quotaOrderNumberOriginExclusion'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'quotaOrderNumberOrigin.sid' => :quota_order_number_origin_sid,
        "#{mapping_path}.geographicalArea.sid" => :excluded_geographical_area_sid
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
