module Api
  module V2
    module GreenLanes
      class SubheadingsController < ApiController
        def show
          subheading = ::GreenLanes::FetchSubheadingsService.new(params[:id]).call
          serializer = Api::V2::GreenLanes::SubheadingSerializer.new(subheading)

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
