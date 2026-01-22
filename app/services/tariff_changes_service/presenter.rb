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

    def classification_description
      TimeMachine.at(goods_nomenclature.validity_start_date) do
        goods_nomenclature.classification_description
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

    def date_of_effect
      super.strftime('%d/%m/%Y')
    end

    def ott_url
      date = __getobj__.date_of_effect
      "https://www.trade-tariff.service.gov.uk/commodities/#{goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}"
    end

    def api_url
      date = __getobj__.date_of_effect.strftime('%Y-%m-%d')
      "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{goods_nomenclature_item_id}?as_of=#{date}"
    end
  end
end
