class TariffChangesService
  module Presenter
    def commodity_description(commodity)
      TimeMachine.at(commodity.validity_start_date) do
        commodity.goods_nomenclature_description.csv_formatted_description
      end
    end

    def measure_type(measure)
      return 'N/A' if measure.blank?

      measure.measure_type.description
    end

    def import_export(measure)
      return 'N/A' if measure.blank?

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
      return 'N/A' if geo_area.blank?

      description = geo_area.erga_omnes? ? 'All countries' : geo_area.description
      geo_area_string = "#{description} (#{geo_area.id})"

      if excluded_geographical_areas.present?
        excluded = excluded_geographical_areas.map(&:description).join(', ')
        geo_area_string += " excluding #{excluded}"
      end

      geo_area_string
    end
  end
end
