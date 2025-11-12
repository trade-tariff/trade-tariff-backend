module TariffChanges
  class GroupedMeasureChange
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :trade_direction, :string
    attribute :count, :integer
    attribute :geographical_area_id, :string
    attribute :excluded_geographical_area_ids
    attribute :commodities, default: -> { [] }

    def self.from_id(id)
      parts = id.split('_')
      new(
        trade_direction: parts[0],
        geographical_area_id: parts[1],
        excluded_geographical_area_ids: parts[2].present? ? parts[2].split('-') : [],
      )
    end

    def id
      "#{trade_direction}_#{geographical_area_id}_#{excluded_geographical_area_ids.sort.join('-')}"
    end

    def geographical_area
      return nil unless geographical_area_id

      @geographical_area ||= GeographicalArea.find(geographical_area_id: geographical_area_id)
    end

    def excluded_geographical_areas
      return [] if excluded_geographical_area_ids.blank?

      ids = Array(excluded_geographical_area_ids).compact
      return [] if ids.empty?

      @excluded_geographical_areas ||= GeographicalArea.where(geographical_area_id: ids).all
    end

    def trade_direction_code
      MeasureType::TRADE_DIRECTION.key(trade_direction)
    end

    def grouped_measure_commodity_changes
      @grouped_measure_commodity_changes ||= commodities.map do |commodity_data|
        GroupedMeasureCommodityChange.new(
          commodity_data.merge(grouped_measure_change_id: id),
        )
      end
    end

    def add_commodity_change(commodity_change_attributes)
      commodities << commodity_change_attributes
      @grouped_measure_commodity_changes = nil # Reset memoization
      grouped_measure_commodity_changes.last
    end
  end
end
