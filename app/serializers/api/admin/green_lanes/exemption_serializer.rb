module Api
  module Admin
    module GreenLanes
      class ExemptionSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_exemption

        set_id :id

        attributes :code,
                   :description
      end
    end
  end
end
