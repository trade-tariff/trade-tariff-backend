module Api
  module V2
    class QuotaOrderNumbersController < ApiController
      TTL = 1.day

      def index
        render json: serialized_quota_order_numbers
      end

      private

      def serialized_quota_order_numbers
        Rails.cache.fetch(cache_key, expires_in: TTL) do
          Api::V2::QuotaOrderNumberSerializer.new(
            quota_order_numbers,
            include: [:quota_definition],
          ).serializable_hash
        end
      end

      def cache_key
        "_quota-order-numbers-#{actual_date.iso8601}"
      end

      def quota_order_numbers
        QuotaOrderNumber.with_quota_definitions
      end
    end
  end
end
