class TariffChangesService
  class Presenter < SimpleDelegator
    attr_reader :geo_area_cache

    def initialize(tariff_change, geo_area_cache = {})
      super(tariff_change)
      @geo_area_cache = geo_area_cache
    end

    def type
      {
        'GoodsNomenclatureDescription' => 'Commodity Description',
      }[super] || super
    end

    def commodity_description
      TimeMachine.at(goods_nomenclature.validity_start_date) do
        goods_nomenclature.goods_nomenclature_description.csv_formatted_description
      end
    end

    def measure_type
      return 'N/A' if measure_type_id.blank?

      measure.measure_type.description
    end

    def import_export
      return 'N/A' if trade_movement_code.nil?

      case trade_movement_code
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

    def geo_area
      return 'N/A' if geographical_area_id.blank?

      geo_area = @geo_area_cache[geographical_area_id]
      return 'N/A' unless geo_area

      description = geo_area.erga_omnes? ? 'All countries' : geo_area.description
      geo_area_string = "#{description} (#{geo_area.id})"

      if excluded_geographical_area_ids.present?
        excluded = excluded_geographical_area_ids.map { |id| @geo_area_cache[id]&.description }.compact.join(', ')
        geo_area_string += " excluding #{excluded}" if excluded.present?
      end

      geo_area_string
    end

    def additional_code
      return 'N/A' if super.blank?

      super
    end
  end
end
