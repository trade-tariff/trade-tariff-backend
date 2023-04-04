module Api
  module Admin
    module QuotaOrderNumbers
      class MeasurementUnitSerializer
        include JSONAPI::Serializer

        set_type :measurement_unit

        attributes :description, :measurement_unit_code, :abbreviation
      end
    end
  end
end
