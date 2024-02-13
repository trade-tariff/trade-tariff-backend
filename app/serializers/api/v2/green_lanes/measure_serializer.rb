module Api
  module V2
    module GreenLanes
      class MeasureSerializer
        include JSONAPI::Serializer

        set_id :measure_sid

        attributes :effective_start_date,
                   :effective_end_date
      end
    end
  end
end
