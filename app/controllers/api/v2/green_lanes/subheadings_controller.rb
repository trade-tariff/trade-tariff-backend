module Api
  module V2
    module GreenLanes
      class SubheadingsController < BaseController
        def show
          subheading = ::GreenLanes::FetchSubheadingsService.new(params[:id]).call
          possible_categorisations = ::GreenLanes::CategorisationsService.new.find_possible_categorisations(subheading)
          presented_subheading = SubheadingPresenter.new(subheading, possible_categorisations)
          serializer = Api::V2::GreenLanes::SubheadingSerializer.new(presented_subheading, include: %w[applicable_measures possible_categorisations])

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
