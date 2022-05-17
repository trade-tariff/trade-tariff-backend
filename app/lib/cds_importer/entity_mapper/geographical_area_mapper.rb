class CdsImporter
  class EntityMapper
    class GeographicalAreaMapper < BaseMapper
      self.entity_class = 'GeographicalArea'.freeze

      self.mapping_root = 'GeographicalArea'.freeze

      self.entity_mapping = base_mapping.merge(
        'hjid' => :hjid,
        'sid' => :geographical_area_sid,
        'geographicalCode' => :geographical_code,
        'geographicalAreaId' => :geographical_area_id,
        'parentGeographicalAreaGroupSid' => :parent_geographical_area_group_sid,
      ).freeze
    end
  end
end
