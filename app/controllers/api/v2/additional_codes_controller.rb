module Api
  module V2
    class AdditionalCodesController < ApiController
      def search
        render json: AdditionalCodeSearchService.new(params).call
      end
    end
  end
end
