module Api
  module V2
    class QuotaOrderNumbersController < ApiController
      def index
        render json: Api::V2::QuotaOrderNumberSerializer.new(quota_order_numbers, include: [:quota_definition]).serializable_hash
      end

      private

      def quota_order_numbers
        QuotaOrderNumber.with_quota_definitions
      end
    end
  end
end
