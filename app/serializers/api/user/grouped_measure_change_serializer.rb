module Api
  module User
    class GroupedMeasureChangeSerializer
      include JSONAPI::Serializer

      set_type :grouped_measure_change

      set_id :id

      attributes :trade_direction, :count

      belongs_to :geographical_area, serializer: Api::V2::GeographicalAreaSerializer, &:geographical_area
      has_many :excluded_countries, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer, &:excluded_geographical_areas
      has_many :grouped_measure_commodity_changes, record_type: :grouped_measure_commodity_change, serializer: Api::User::GroupedMeasureCommodityChangeSerializer, &:grouped_measure_commodity_changes
    end
  end
end
