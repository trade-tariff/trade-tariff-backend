module Api
  module V3
    class QuotaOrderNumbersController < BaseController
      def index
        quota_order_numbers = QuotaOrderNumber.with_quota_definitions.all
        render json: Api::V3::QuotaOrderNumberSerializer.collection(quota_order_numbers)
      end
    end
  end
end
