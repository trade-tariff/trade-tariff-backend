module Api
  module V2
    class MeasureActionSerializer
      include JSONAPI::Serializer

      set_type :measure_action

      set_id :action_code

      attributes :description,
                 :validity_start_date,
                 :validity_end_date
    end
  end
end
