# SearchLabels controls whether AI-generated label fields are included in search queries.
#
# When enabled, searches will include:
# - labels.description (AI-enhanced description)
# - labels.known_brands (e.g., "iPhone", "Samsung Galaxy")
# - labels.colloquial_terms (common names)
# - labels.synonyms (alternative terms)
#
# Used by the internal search API to enrich OpenSearch queries with label data:
#
#   results = SearchLabels.with_labels do
#     TradeTariffBackend.search_client.search(
#       Search::GoodsNomenclatureQuery.new(q, as_of).query,
#     )
#   end
#
module SearchLabels
  class << self
    def with_labels
      raise ArgumentError, 'requires a block' unless block_given?

      previous = TradeTariffRequest.search_labels_enabled
      TradeTariffRequest.search_labels_enabled = true
      yield
    ensure
      TradeTariffRequest.search_labels_enabled = previous
    end

    def without_labels
      raise ArgumentError, 'requires a block' unless block_given?

      previous = TradeTariffRequest.search_labels_enabled
      TradeTariffRequest.search_labels_enabled = false
      yield
    ensure
      TradeTariffRequest.search_labels_enabled = previous
    end

    def enabled?
      TradeTariffRequest.search_labels_enabled == true
    end

    def disabled?
      !enabled?
    end
  end
end
