module Api
  module V2
    module GreenLanes
      class CategorisationSerializer
        include JSONAPI::Serializer

        set_type :green_lanes_categorisation

        set_id :id

        attributes :category,
                   :regulation_id,
                   :measure_type_id,
                   :geographical_area,
                   :document_codes,
                   :additional_codes
      end
    end
  end
end
