module Api
  module Beta
    UnrecognisedFilterError = Class.new(ArgumentError)

    class GoodsNomenclatureFilterGeneratorService
      def initialize(filters)
        @filters = filters
      end

      def call
        @filters.each_with_object([]) do |(filter, term), acc|
          if static_filter?(filter)
            acc << static_filter_for(filter, term)
          elsif facet_filter?(filter)
            acc << dynamic_filter_for(filter, term)
          else
            raise UnrecognisedFilterError, "Unknown filter #{filter}. Please review documentation."
          end
        end
      end

      private

      def static_filter_for(filter, term)
        {
          term: {
            filter.to_sym => term,
          },
        }
      end

      def dynamic_filter_for(filter, term)
        terms = all_classification_permutations_for(filter, term)

        {
          terms: {
            "filter_#{filter}".to_sym => terms,
            boost: boost_for(filter),
          },
        }
      end

      def all_classification_permutations_for(filter, target_classification)
        classifications = TradeTariffBackend
          .search_facet_classifier_configuration
          .facet_classifiers[filter].to_a

        classifications -= [target_classification]

        terms = []

        classifications.length.downto(0) do
          term = classifications.dup.concat([target_classification]).sort.join('|')
          terms << term
          classifications.pop
        end

        terms
      end

      def static_filter?(filter)
        TradeTariffBackend.search_facet_classifier_configuration.static_filter?(filter)
      end

      def facet_filter?(filter)
        TradeTariffBackend.search_facet_classifier_configuration.dynamic_filter?(filter)
      end

      def boost_for(filter)
        TradeTariffBackend.search_facet_classifier_configuration.boost_for(filter)
      end
    end
  end
end
