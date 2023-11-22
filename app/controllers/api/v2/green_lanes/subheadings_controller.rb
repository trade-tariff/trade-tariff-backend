module Api
  module V2
    module GreenLanes
      class SubheadingsController < ApiController
        def show
          subheading = ::GreenLanes::FetchSubheadingsService.new(params[:id]).call
          presented_subheading = SubheadingPresenter.new(subheading)
          serializer = Api::V2::GreenLanes::SubheadingSerializer.new(presented_subheading, include: ['applicable_measures'])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
