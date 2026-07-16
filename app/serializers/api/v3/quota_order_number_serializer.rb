module Api
  module V3
    class QuotaOrderNumberSerializer
      def initialize(quota_order_number)
        @quota_order_number = quota_order_number
      end

      def call
        {
          quota_order_number_sid: @quota_order_number.quota_order_number_sid,
          quota_order_number_id: @quota_order_number.quota_order_number_id,
          validity_start_date: @quota_order_number.validity_start_date,
          validity_end_date: @quota_order_number.validity_end_date,
        }
      end

      def self.collection(quota_order_numbers)
        list = quota_order_numbers.map { |q| new(q).call }
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
