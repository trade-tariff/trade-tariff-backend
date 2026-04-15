class OpensearchRetrievalService
  Result = Struct.new(:results, :expanded_query, keyword_init: true)

  def self.call(query:, as_of:, request_id: nil, limit: 30, filter_prefixes: [])
    new(query:, as_of:, request_id:, limit:, filter_prefixes:).call
  end

  def initialize(query:, as_of:, request_id: nil, limit: 30, filter_prefixes: [])
    @query = query
    @as_of = as_of
    @request_id = request_id
    @limit = limit
    @filter_prefixes = Array(filter_prefixes).compact_blank
  end

  def call
    expanded = expand_query(@query)
    hits = run_search(expanded)
    Result.new(results: hits.map { |h| build_result_from_hit(h) }, expanded_query: expanded)
  end

  private

  def run_search(expanded_query)
    results = search_with_configured_labels do
      TradeTariffBackend.search_client.search(
        ::Search::GoodsNomenclatureQuery.new(
          @query,
          @as_of,
          expanded_query: expanded_query,
          pos_search: pos_search_enabled?,
          size: @limit,
          noun_boost: pos_noun_boost,
          qualifier_boost: pos_qualifier_boost,
          filter_prefixes: @filter_prefixes,
        ).query,
      )
    end

    results.dig('hits', 'hits') || []
  end

  def expand_query(query)
    return query unless expand_search_enabled?

    result = ::Search::Instrumentation.query_expanded(
      request_id: @request_id,
      original_query: query,
    ) { ExpandSearchQueryService.call(query) }

    result.expanded_query
  end

  def expand_search_enabled?
    AdminConfiguration.enabled?('expand_search_enabled')
  end

  def pos_search_enabled?
    AdminConfiguration.enabled?('pos_search_enabled')
  end

  def pos_noun_boost
    AdminConfiguration.integer_value('pos_noun_boost')
  end

  def pos_qualifier_boost
    AdminConfiguration.integer_value('pos_qualifier_boost')
  end

  def search_with_configured_labels(&block)
    if AdminConfiguration.enabled?('search_labels_enabled')
      SearchLabels.with_labels(&block)
    else
      SearchLabels.without_labels(&block)
    end
  end

  def build_result_from_hit(hit)
    source = hit['_source']
    GoodsNomenclatureResult.new(
      id: source['goods_nomenclature_sid'],
      goods_nomenclature_item_id: source['goods_nomenclature_item_id'],
      goods_nomenclature_sid: source['goods_nomenclature_sid'],
      producline_suffix: source['producline_suffix'],
      goods_nomenclature_class: source['goods_nomenclature_class'],
      description: source['description'],
      formatted_description: source['formatted_description'],
      self_text: source['self_text'],
      classification_description: source['classification_description'],
      full_description: source['full_description'],
      heading_description: source['heading_description'],
      declarable: source['declarable'],
      score: hit['_score'],
      confidence: nil,
    )
  end
end
