module GreenLanes
  class Measure < Sequel::Model(:green_lanes_measures)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    many_to_one :category_assessment
    many_to_one :goods_nomenclature, class: 'GoodsNomenclature',
                                     primary_key: %i[goods_nomenclature_item_id producline_suffix],
                                     key: %i[goods_nomenclature_item_id productline_suffix]
    delegate :goods_nomenclature_sid, to: :goods_nomenclature

    many_to_one :geographical_area, class: 'GeographicalArea',
                                    primary_key: :geographical_area_id,
                                    key: :geographical_area_id do |ds|
      ds.with_actual(::GeographicalArea)
    end

    delegate :measure_type_id, :measure_type, to: :category_assessment

    alias_method :effective_start_date, :created_at

    # simulate the filtering interface on tariff measures
    # true because GL measures always apply to all regions
    def relevant_for_country?(_geographical_area_id)
      true
    end

    def measure_generating_regulation_id
      category_assessment.regulation_id
    end

    def measure_generating_regulation_role
      category_assessment.regulation_role
    end

    def generating_regulation
      category_assessment.regulation
    end

    def geographical_area_id
      GeographicalArea::ERGA_OMNES_ID
    end

    def measure_excluded_geographical_areas
      []
    end

    def excluded_geographical_areas
      []
    end

    def additional_code_type_id
      nil
    end

    def additional_code_id
      nil
    end

    def additional_code
      nil
    end

    def measure_conditions
      []
    end

    def footnotes
      []
    end

    def measure_sid
      @measure_sid ||= sprintf('gl%06d', id)
    end

    def effective_end_date
      nil
    end
  end
end
