module GreenLanes
  class FindCategorisationsService
    class << self
      def call(goods_nomenclature:, origin: nil)
        goods_nomenclature.applicable_measures.flat_map do |measure|
          Categorisation.filter(regulation_id: measure.measure_generating_regulation_id,
                                measure_type_id: measure.measure_type_id,
                                geographical_area: origin)
        end
      end
    end
  end
end
