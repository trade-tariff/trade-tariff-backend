module GreenLanes
  class CategorisationsService
    def find_possible_categorisations(subheading)
      subheading.applicable_measures.flat_map do |measure|
        Categorisation.filter(regulation_id: measure.measure_generating_regulation_id, measure_type_id: measure.measure_type_id)
      end
    end
  end
end
