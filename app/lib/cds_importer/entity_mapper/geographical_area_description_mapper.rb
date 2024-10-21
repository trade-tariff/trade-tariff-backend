class CdsImporter
  class EntityMapper
    class GeographicalAreaDescriptionMapper < BaseMapper
      self.entity_class = 'GeographicalAreaDescription'.freeze

      self.mapping_root = 'GeographicalArea'.freeze

      self.mapping_path = 'geographicalAreaDescriptionPeriod.geographicalAreaDescription'.freeze

      self.exclude_mapping = %w[validityStartDate validityEndDate].freeze

      self.entity_mapping = base_mapping.merge(
        'geographicalAreaDescriptionPeriod.sid' => :geographical_area_description_period_sid,
        "#{mapping_path}.language.languageId" => :language_id,
        'sid' => :geographical_area_sid,
        'geographicalAreaId' => :geographical_area_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
