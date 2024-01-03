module Api
  module V2
    module GreenLanes
      class CategorisationsController < ApiController
        def index
          categorisation = ::GreenLanes::Categorisation.load_from_file
          serializer = Api::V2::GreenLanes::CategorisationSerializer.new(categorisation)

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
