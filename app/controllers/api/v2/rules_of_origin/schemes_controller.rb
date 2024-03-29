module Api
  module V2
    module RulesOfOrigin
      class SchemesController < ApiController
        DEFAULT_INCLUDES = %i[links origin_reference_document].freeze
        OPTIONAL_INCLUDES = %i[proofs].freeze

        def index
          query = ::RulesOfOrigin::Query.new(
            TradeTariffBackend.rules_of_origin,
            params[:heading_code],
            params[:country_code],
            params[:filter]&.permit(*::RulesOfOrigin::Query::SUPPORTED_FILTERS)
                           &.to_hash,
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
          Api::V2::RulesOfOrigin::SchemeSerializer.new schemes, include: includes
        end

        def includes
          (params[:include].to_s.split(/\s+/).map(&:to_sym) & OPTIONAL_INCLUDES) + DEFAULT_INCLUDES
        end
      end
    end
  end
end
