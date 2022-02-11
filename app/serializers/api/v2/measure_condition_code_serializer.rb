module Api
  module V2
    class MeasureConditionCodeSerializer
      include JSONAPI::Serializer

      set_type :measure_condition_code

      set_id :condition_code

      attributes :description,
                 :validity_start_date,
                 :validity_end_date
    end
  end
end
