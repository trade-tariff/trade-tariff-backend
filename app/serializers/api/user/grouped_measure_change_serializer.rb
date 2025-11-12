module Api
  module User
    class GroupedMeasureChangeSerializer
      include JSONAPI::Serializer

      set_type :grouped_measure_change

      attributes :trade_direction, :count

      belongs_to :geographical_area, serializer: Api::V2::GeographicalAreaSerializer, &:geographical_area
      has_many :excluded_countries, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer, &:excluded_geographical_areas
    end
  end
end
