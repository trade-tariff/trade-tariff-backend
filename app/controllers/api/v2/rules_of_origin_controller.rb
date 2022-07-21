module Api
  module V2
    class RulesOfOriginController < ApiController
      def index
        query = ::RulesOfOrigin::Query.new(
          TradeTariffBackend.rules_of_origin,
          params[:heading_code],
          params[:country_code],
        )

        presented_schemes = Api::V2::RulesOfOrigin::SchemePresenter.for_many(
          query.schemes,
          query.rules,
          query.scheme_rule_sets,
        )

        includes = %i[links proofs rules articles]
        includes += %i[rule_sets rule_sets.rules] if TradeTariffBackend.roo_v2_data

        @serializer = Api::V2::RulesOfOrigin::SchemeSerializer.new(
          presented_schemes,
          include: includes,
        )

        render json: @serializer.serializable_hash
      end
    end
  end
end
