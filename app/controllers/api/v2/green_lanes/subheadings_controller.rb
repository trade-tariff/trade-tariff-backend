module Api
  module V2
    module GreenLanes
      class SubheadingsController < ApiController
        def show
          subheading_measures = ::GreenLanes::FetchSubheadingsService.new(params[:id]).call
          presented_subheading = SubheadingPresenter.new(subheading_measures)
          serializer = Api::V2::GreenLanes::SubheadingMeasuresSerializer.new(presented_subheading)

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
