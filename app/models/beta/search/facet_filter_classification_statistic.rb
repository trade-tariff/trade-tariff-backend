module Beta
  module Search
    class FacetFilterClassificationStatistic
      attr_accessor :facet_filter, :classification, :count

      include ContentAddressableId

      content_addressable_fields :facet, :classification, :count

      def facet
        facet_filter.sub('filter_', '')
      end

      def self.build(statistic)
        facet_filter_statistic = new

        facet_filter_statistic.facet_filter = statistic['filter_facet']
        facet_filter_statistic.classification = statistic['classification']
        facet_filter_statistic.count = statistic['count']

        facet_filter_statistic
      end
    end
  end
end
