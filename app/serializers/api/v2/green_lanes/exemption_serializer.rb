module Api
  module V2
    module GreenLanes
      class ExemptionSerializer
        include JSONAPI::Serializer

        set_id :code

        attributes :code,
                   :description,
                   :formatted_description
      end
    end
  end
end
