class TariffChangesService
  class Presenter < SimpleDelegator
    attr_reader :geo_area_cache, :eu_member_ids

    UTM_TAGS = 'utm_source=offline&utm_medium=excel&utm_campaign=change_data'.freeze

    def initialize(tariff_change, geo_area_cache = {}, eu_member_ids = [])
      super(tariff_change)
      @geo_area_cache = geo_area_cache
      @eu_member_ids = eu_member_ids
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
        geo_area_string += format_excluded_areas
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
      "https://www.trade-tariff.service.gov.uk/commodities/#{goods_nomenclature_item_id}?day=#{date_of_effect_visible.day}&month=#{date_of_effect_visible.month}&year=#{date_of_effect_visible.year}&#{UTM_TAGS}"
    end

    def api_url
      "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{goods_nomenclature_item_id}?as_of=#{date_of_effect_visible.strftime('%Y-%m-%d')}&#{UTM_TAGS}"
    end

    private

    def format_excluded_areas
      return '' if excluded_geographical_area_ids.empty?

      eu_excluded = []
      non_eu_excluded = []

      excluded_geographical_area_ids.each do |id|
        if id == 'EU' || @eu_member_ids.include?(id)
          eu_excluded << id
        else
          non_eu_excluded << id
        end
      end

      excluded_parts = []

      # If all EU members are excluded or 'EU' is in the list, show "European Union"
      if eu_excluded.include?('EU') || (eu_excluded.any? && eu_excluded.sort == @eu_member_ids.sort)
        excluded_parts << 'European Union'
      else
        # Otherwise, list individual EU countries
        eu_excluded.each do |id|
          excluded_parts << @geo_area_cache[id]&.description
        end
      end

      # Add non-EU countries
      non_eu_excluded.each do |id|
        excluded_parts << @geo_area_cache[id]&.description
      end

      excluded_descriptions = excluded_parts.compact.join(', ')
      excluded_descriptions.present? ? " excluding #{excluded_descriptions}" : ''
    end
  end
end
