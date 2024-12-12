module Loaders
  class GeographicalArea < Base
    def self.load(file, batch)
      geographical_areas = []
      periods = []
      descriptions = []
      memberships = []

      batch.each do |attributes|
        geographical_areas.push({
          geographical_area_sid: attributes.dig('GeographicalArea', 'sid'),
          parent_geographical_area_group_sid: attributes.dig('GeographicalArea', 'parentGeographicalAreaGroupSid'),
          geographical_code: attributes.dig('GeographicalArea', 'geographicalCode'),
          geographical_area_id: attributes.dig('GeographicalArea', 'geographicalAreaId'),
          hjid: attributes.dig('GeographicalArea', 'hjid'),
          validity_start_date: attributes.dig('GeographicalArea', 'validityStartDate'),
          validity_end_date: attributes.dig('GeographicalArea', 'validityEndDate'),
          operation: attributes.dig('GeographicalArea', 'metainfo', 'opType'),
          operation_date: attributes.dig('GeographicalArea', 'metainfo', 'transactionDate'),
          filename: file,
        })

        period_attributes = if attributes.dig('GeographicalArea', 'geographicalAreaDescriptionPeriod').is_a?(Array)
                              attributes.dig('GeographicalArea', 'geographicalAreaDescriptionPeriod')
                            else
                              Array.wrap(attributes.dig('GeographicalArea', 'geographicalAreaDescriptionPeriod'))
                            end

        period_attributes.each do |period|
          periods.push({
            geographical_area_sid: attributes.dig('GeographicalArea', 'sid'),
            geographical_area_id: attributes.dig('GeographicalArea', 'geographicalAreaId'),
            geographical_area_description_period_sid: period['sid'],
            validity_start_date: period['validityStartDate'],
            validity_end_date: period['validityEndDate'],
            operation: period.dig('metainfo', 'opType'),
            operation_date: period.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          description = period['geographicalAreaDescription']

          next unless description.present? && description.is_a?(Hash)

          descriptions.push({
            geographical_area_sid: attributes.dig('GeographicalArea', 'sid'),
            geographical_area_id: attributes.dig('GeographicalArea', 'geographicalAreaId'),
            geographical_area_description_period_sid: period['sid'],
            language_id: description.dig('language', 'languageId'),
            description: description['description'],
            operation: description.dig('metainfo', 'opType'),
            operation_date: description.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        membership_attributes = if attributes.dig('GeographicalArea', 'geographicalAreaMembership').is_a?(Array)
                                  attributes.dig('GeographicalArea', 'geographicalAreaMembership')
                                else
                                  Array.wrap(attributes.dig('GeographicalArea', 'geographicalAreaMembership'))
                                end

        membership_attributes.each do |membership|
          next unless membership.present? && membership['geographicalAreaGroupSid'].present?

          memberships.push({
            hjid: membership['hjid'],
            geographical_area_sid: membership['geographicalAreaSid'],
            geographical_area_group_sid: membership['geographicalAreaGroupSid'],
            validity_start_date: membership['validityStartDate'],
            validity_end_date: membership['validityEndDate'],
            operation: membership.dig('metainfo', 'opType'),
            operation_date: membership.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('GeographicalArea::Operation').multi_insert(geographical_areas)
      Object.const_get('GeographicalAreaDescriptionPeriod::Operation').multi_insert(periods)
      Object.const_get('GeographicalAreaDescription::Operation').multi_insert(descriptions)
      Object.const_get('GeographicalAreaMembership::Operation').multi_insert(memberships)
    end
  end
end
