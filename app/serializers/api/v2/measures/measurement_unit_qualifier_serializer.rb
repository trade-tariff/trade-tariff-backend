module Api
  module V2
    module Measures
      class MeasurementUnitQualifierSerializer
        include JSONAPI::Serializer

        set_id :measurement_unit_qualifier_code
        set_type :measurement_unit_qualifier

        attribute :description
        attribute :formatted_description, &:formatted_measurement_unit_qualifier
      end
    end
  end
end
