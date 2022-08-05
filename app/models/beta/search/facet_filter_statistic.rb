module Beta
  module Search
    class FacetFilterStatistic
      BOOSTED_FACET = 'entity'.freeze

      include ContentAddressableId

      content_addressable_fields :facet_filter, :facet_count

      attr_accessor :facet_filter,
                    :facet_count,
                    :display_name,
                    :question,
                    :boost,
                    :facet_classification_statistics,
                    :facet_classification_statistic_ids

      def facet
        facet_filter.sub('filter_', '')
      end

      class << self
        def build(statistic)
          facet = statistic['filter_facet']

          classifications = statistic['classifications']
            .values
            .map(&Beta::Search::FacetFilterClassificationStatistic.method(:build))
            .sort_by(&:count)
            .reverse

          facet_filter_statistic = new

          facet_filter_statistic.facet_filter = facet
          facet_filter_statistic.facet_count = statistic['count']
          facet_filter_statistic.facet_classification_statistics = classifications
          facet_filter_statistic.facet_classification_statistic_ids = classifications.map(&:id)
          facet_filter_statistic.display_name = display_name_for(facet_filter_statistic.facet)
          facet_filter_statistic.question = question_for(facet_filter_statistic.facet)
          facet_filter_statistic.boost = boost_for(facet_filter_statistic.facet)

          facet_filter_statistic
        end

        def display_name_for(facet)
          filter_configuration.dig(facet, :friendly_name) || facet.humanize
        end

        def question_for(facet)
          filter_configuration.dig(facet, :question) || "Pick one of #{display_name_for(facet)}"
        end

        def boost_for(filter)
          TradeTariffBackend.search_facet_classifier_configuration.boost_for(filter)
        end

        def filter_configuration
          TradeTariffBackend.search_facet_classifier_configuration.filter_configuration
        end
      end
    end
  end
end
