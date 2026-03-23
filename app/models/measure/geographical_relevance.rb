# frozen_string_literal: true

class Measure
  # Determines whether a Measure is geographically relevant to a given country.
  # Encapsulates erga omnes logic, exclusion lists, and area membership checks.
  class GeographicalRelevance
    def initialize(measure)
      @measure = measure
    end

    def relevant_for?(country_id)
      return false if excluded?(country_id)
      return true if erga_omnes? && (measure.national? || measure.measure_type&.meursing?)
      return true if measure.geographical_area_id.blank? || measure.geographical_area_id == country_id

      contained_area_ids.include?(country_id)
    end

    private

    attr_reader :measure

    def excluded?(country_id)
      country_id.in?(excluded_area_ids)
    end

    def erga_omnes?
      measure.geographical_area_id == GeographicalArea::ERGA_OMNES_ID
    end

    def excluded_area_ids
      measure.excluded_geographical_areas
             .map(&:referenced_or_self)
             .uniq
             .flat_map(&:candidate_excluded_geographical_area_ids)
             .uniq
    end

    def contained_area_ids
      (measure.geographical_area.referenced.presence || measure.geographical_area)
        .contained_geographical_areas
        .pluck(:geographical_area_id)
    end
  end
end
