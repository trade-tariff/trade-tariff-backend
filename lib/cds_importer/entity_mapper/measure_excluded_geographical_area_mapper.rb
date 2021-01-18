#
# MeasureExcludedGeographicalArea is nested in to Measure
#

class CdsImporter
  class EntityMapper
    class MeasureExcludedGeographicalAreaMapper < BaseMapper
      self.entity_class = 'MeasureExcludedGeographicalArea'.freeze

      self.mapping_root = 'Measure'.freeze

      self.mapping_path = 'measureExcludedGeographicalArea'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        "#{mapping_path}.geographicalArea.geographicalAreaId" => :excluded_geographical_area,
        "#{mapping_path}.geographicalArea.sid" => :geographical_area_sid
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
