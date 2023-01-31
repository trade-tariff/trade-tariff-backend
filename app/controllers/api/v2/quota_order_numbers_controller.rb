module Api
  module V2
    class QuotaOrderNumbersController < ApiController
      def index
        render json: CachedQuotaOrderNumberService.new.call
      end
    end
  end
end
