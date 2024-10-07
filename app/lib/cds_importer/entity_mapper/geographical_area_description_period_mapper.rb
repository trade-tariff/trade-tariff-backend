class CdsImporter
  class EntityMapper
    class GeographicalAreaDescriptionPeriodMapper < BaseMapper
      self.entity_class = 'GeographicalAreaDescriptionPeriod'.freeze

      self.mapping_root = 'GeographicalArea'.freeze

      self.mapping_path = 'geographicalAreaDescriptionPeriod'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :geographical_area_description_period_sid,
        'sid' => :geographical_area_sid,
        'geographicalAreaId' => :geographical_area_id,
      ).freeze
    end
  end
end
