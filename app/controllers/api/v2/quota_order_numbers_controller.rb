module Api
  module V2
    class QuotaOrderNumbersController < ApiController
      DEFAULT_INCLUDES = %w[quota_definition quota_definition.measures].freeze
      EAGER_LOAD = {
        quota_definition: {
          measurement_unit: %i[measurement_unit_description
                               measurement_unit_abbreviations],
          measures: [],
        },
      }.freeze

      def index
        quota_order_numbers = QuotaOrderNumber.with_quota_definitions.eager(EAGER_LOAD).all

        render json: Api::V2::QuotaOrderNumbers::QuotaOrderNumberSerializer.new(
          quota_order_numbers,
          include: DEFAULT_INCLUDES,
        ).serializable_hash
      end
    end
  end
end
