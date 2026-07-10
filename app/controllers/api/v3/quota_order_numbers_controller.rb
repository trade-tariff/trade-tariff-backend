module Api
  module V3
    class QuotaOrderNumbersController < BaseController
      def index
        render json: CachedQuotaOrderNumberService.new.call
      end
    end
  end
end
