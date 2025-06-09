module Api
  module Admin
    module GreenLanes
      class MeasureTypeMappingSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_measure_type_mapping

        set_id :id

        attributes :measure_type_id, :theme_id

        has_one :theme, serializer: ThemeSerializer
      end
    end
  end
end
