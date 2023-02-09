module Api
  module V2
    module RulesOfOrigin
      class ProductSpecificRulesController < ApiController
        def index
          schemes = TradeTariffBackend.rules_of_origin.scheme_set.all_schemes
          rule_sets = schemes.index_by(&:scheme_code)
                             .transform_values(&method(:rule_sets_for_scheme))

          presented_schemes = RulesOfOrigin::SchemePresenter.for_many(schemes, {}, rule_sets)
          render json: serializer(presented_schemes).serializable_hash
        end

      private

        def serializer(schemes)
          Api::V2::RulesOfOrigin::SchemeSerializer.new schemes, include: %i[
            rule_sets
            rule_sets.rules
          ]
        end

        def rule_sets_for_scheme(scheme)
          scheme.rule_sets_for_subheading params[:commodity_code]
        end
      end
    end
  end
end
