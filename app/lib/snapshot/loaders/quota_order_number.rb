module Loaders
  class QuotaOrderNumber < Base
    def self.load(file, batch)
      quota_orders = []
      origins = []
      exclusions = []

      batch.each do |attributes|
        quota_orders.push({
          quota_order_number_sid: attributes.dig('QuotaOrderNumber', 'sid'),
          quota_order_number_id: attributes.dig('QuotaOrderNumber', 'quotaOrderNumberId'),
          validity_start_date: attributes.dig('QuotaOrderNumber', 'validityStartDate'),
          validity_end_date: attributes.dig('QuotaOrderNumber', 'validityEndDate'),
          operation: attributes.dig('QuotaOrderNumber', 'metainfo', 'opType'),
          operation_date: attributes.dig('QuotaOrderNumber', 'metainfo', 'transactionDate'),
          filename: file,
        })

        origin_attributes = if attributes.dig('QuotaOrderNumber', 'quotaOrderNumberOrigin').is_a?(Array)
                              attributes.dig('QuotaOrderNumber', 'quotaOrderNumberOrigin')
                            else
                              Array.wrap(attributes.dig('QuotaOrderNumber', 'quotaOrderNumberOrigin'))
                            end

        origin_attributes.each do |origin|
          next unless origin.is_a?(Hash)

          origins.push({
            quota_order_number_sid: attributes.dig('QuotaOrderNumber', 'sid'),
            quota_order_number_origin_sid: origin['sid'],
            geographical_area_id: origin.dig('geographicalArea', 'geographicalAreaId'),
            geographical_area_sid: origin.dig('geographicalArea', 'sid'),
            validity_start_date: origin['validityStartDate'],
            validity_end_date: origin['validityEndDate'],
            operation: origin.dig('metainfo', 'opType'),
            operation_date: origin.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          exclusion_attributes = if origin['quotaOrderNumberOriginExclusions'].is_a?(Array)
                                   origin['quotaOrderNumberOriginExclusions']
                                 else
                                   Array.wrap(origin['quotaOrderNumberOriginExclusions'])
                                 end

          exclusion_attributes.each do |exclusion|
            next unless exclusion.is_a?(Hash)

            exclusions.push({
              quota_order_number_origin_sid: origin['sid'],
              excluded_geographical_area_sid: exclusion.dig('geographicalArea', 'sid'),
              operation: exclusion.dig('metainfo', 'opType'),
              operation_date: exclusion.dig('metainfo', 'transactionDate'),
              filename: file,
            })
          end
        end
      end

      Object.const_get('QuotaOrderNumber::Operation').multi_insert(quota_orders)
      Object.const_get('QuotaOrderNumberOrigin::Operation').multi_insert(origins)
      Object.const_get('QuotaOrderNumberOriginExclusion::Operation').multi_insert(exclusions)
    end
  end
end
