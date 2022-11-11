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

        if query.querying_for_rules?
          render json: full_serializer(presented_schemes).serializable_hash
        else
          render json: minimal_serializer(presented_schemes).serializable_hash
        end
      end

    private

      def full_serializer(schemes)
        Api::V2::RulesOfOrigin::FullSchemeSerializer.new schemes, include: %i[
          links
          proofs
          rules
          articles
          rule_sets
          rule_sets.rules
          origin_reference_document
        ]
      end

      def minimal_serializer(schemes)
        Api::V2::RulesOfOrigin::SchemeSerializer.new schemes, include: %i[
          links
          origin_reference_document
        ]
      end
    end
  end
end
