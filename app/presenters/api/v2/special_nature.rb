module Api
  module V2
    module SpecialNature
      def special_nature?(presented_measure)
        if !@filtering_by_country && presented_measure.geographical_area_id.match?(/^\D+$/)
          filtered_measures = import_measures.reject { |measure| measure.geographical_area_id != presented_measure.geographical_area_id && measure.geographical_area_id != GeographicalArea::ERGA_OMNES_ID }

          @special_nature = filtered_measures.any?(&:special_nature?)
        else
          @special_nature = import_measures.any?(&:special_nature?)
        end
      end
    end
  end
end
