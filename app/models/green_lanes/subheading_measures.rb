module GreenLanes
  class SubheadingMeasures
    attr_accessor :goods_nomenclature_sid,
                  :subheading,
                  :applicable_measures

    def initialize(subheading, applicable_measures)
      @goods_nomenclature_sid = subheading.goods_nomenclature_sid
      @subheading = subheading
      @applicable_measures = applicable_measures
    end

    def subheading_id
      @subheading.id
    end

    def applicable_measure_ids
      @applicable_measures.map(&:id)
    end
  end
end
