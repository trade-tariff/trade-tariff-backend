module Api
  module Beta
    class SearchFacetStatisticService
      def initialize(goods_nomenclature_hits)
        @goods_nomenclature_hits = goods_nomenclature_hits
      end

      def call
        facet_classification_statistics = @goods_nomenclature_hits.each_with_object({}) do |hit, acc|
          hit.facet_filters.each do |filter_facet|
            acc[filter_facet] ||= {}
            acc[filter_facet]['classifications'] ||= {}
            acc[filter_facet]['count'] ||= 0
            acc[filter_facet]['count'] += 1
            acc[filter_facet]['filter_facet'] = filter_facet

            facet_classifications = hit.public_send(filter_facet).split('|')
            facet_classifications.each do |classification|
              acc[filter_facet]['classifications'][classification] ||= {}
              acc[filter_facet]['classifications'][classification]['count'] ||= 0
              acc[filter_facet]['classifications'][classification]['count'] += 1
              acc[filter_facet]['classifications'][classification]['filter_facet'] = filter_facet
              acc[filter_facet]['classifications'][classification]['classification'] = classification
            end
          end
        end

        facet_classification_statistics.values.map(&::Beta::Search::FacetFilterStatistic.method(:build))
      end
    end
  end
end
