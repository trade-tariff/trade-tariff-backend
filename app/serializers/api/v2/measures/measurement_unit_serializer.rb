module Api
  module V2
    module Measures
      class MeasurementUnitSerializer
        include JSONAPI::Serializer

        set_type :measurement_unit

        attributes :description, :measurement_unit_code
      end
    end
  end
end
