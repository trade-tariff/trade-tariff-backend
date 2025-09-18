class DeltaReportService
  module MeasurePresenter
    def measure_type(measure)
      measure.measure_type.description
    end

    def import_export(measure)
      case measure.measure_type&.trade_movement_code
      when 0
        'Import'
      when 1
        'Export'
      when 2
        'Both'
      else
        ''
      end
    end

    def geo_area(geo_area, excluded_geographical_areas = nil)
      geo_area_string = ''

      if geo_area.present?
        description = geo_area.erga_omnes? ? 'All countries' : geo_area.description
        geo_area_string = "#{description} (#{geo_area.id})"

        if excluded_geographical_areas.present?
          excluded = excluded_geographical_areas.map(&:description).join(', ')
          geo_area_string += " excluding #{excluded}"
        end
      end

      geo_area_string
    end

    def additional_code(additional_code)
      return nil if additional_code.blank? || additional_code.additional_code_description.blank?

      "#{additional_code.code}: #{additional_code.description}"
    end

    def duty_expression(measure)
      measure.supplementary_unit_duty_expression || measure.duty_expression
    end
  end
end
