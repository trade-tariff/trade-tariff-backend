module Api
  module V2
    class RulesOfOriginController < ApiController
      def index
        @query = ::RulesOfOrigin::Query.new(
          TradeTariffBackend.rules_of_origin,
          params[:heading_code],
          params[:country_code],
        )

        @presented_schemes = Api::V2::RulesOfOrigin::SchemePresenter.for_many(
          @query.schemes,
          @query.rules,
        )

        @serializer = Api::V2::RulesOfOrigin::SchemeSerializer.new(
          @presented_schemes,
          include: %i[rules],
        )

        render json: @serializer.serializable_hash
      end
    end
  end
end
