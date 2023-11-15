module Api
  module V2
    module GreenLanes
      class SubheadingsController < ApiController

        def show
          render json: {data: 'Rasika'}
        end

      end
    end
  end
end
