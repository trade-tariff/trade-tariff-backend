module Api
  module V2
    class ValidityPeriodsController < ApiController
      def index
        render json: ValidityPeriodSerializerService.new(params).call
      end
    end
  end
end
