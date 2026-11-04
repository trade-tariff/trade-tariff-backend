# frozen_string_literal: true

class Measure
  # Determines whether a Measure is geographically relevant to a given country.
  # Encapsulates erga omnes logic, exclusion lists, and area membership checks.
  class GeographicalRelevance
    # The single country rule. It takes plain values so that it can run on a
    # Measure and on pre-computed facts about a Measure (the cached commodity
    # response). The block returns the contained area ids. It runs only when
    # the earlier rules do not decide, because it can cost a database query.
    def self.relevant?(country_id:, geographical_area_id:, national:, meursing_type:, excluded_area_ids:)
      return false if country_id.in?(excluded_area_ids)

      erga_omnes = geographical_area_id == GeographicalArea::ERGA_OMNES_ID
      return true if erga_omnes && (national || meursing_type)
      return true if geographical_area_id.blank? || geographical_area_id == country_id

      yield.include?(country_id)
    end

    def initialize(measure)
      @measure = measure
    end

    def relevant_for?(country_id)
      self.class.relevant?(
        country_id: country_id,
        geographical_area_id: measure.geographical_area_id,
        national: measure.national?,
        meursing_type: measure.measure_type&.meursing?,
        excluded_area_ids: excluded_area_ids,
      ) { contained_area_ids }
    end

  private

    attr_reader :measure

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
