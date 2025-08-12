class DeltaReportService
  module MeasurePresenter
    def measure_type(measure)
      "#{measure.measure_type.id}: #{measure.measure_type.description}"
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

    def geo_area(geo_area)
      if geo_area.present?
        "#{geo_area.id}: #{geo_area.description}"
      else
        ''
      end
    end

    def additional_code(measure)
      return nil if measure.additional_code.blank?

      "#{measure.additional_code.code}: #{measure.additional_code.description}"
    end

    def duty_expression(measure)
      measure.duty_expression
    end
  end
end
