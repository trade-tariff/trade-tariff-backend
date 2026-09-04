class VectorRetrievalService
  EmbeddingGenerationError = Class.new(StandardError)
  VectorRetrievalError = Class.new(StandardError)
  Result = Data.define(:results, :max_score)

  def self.call(query:, limit: 80, filter_prefixes: [], request_id: nil, vector_score_threshold: nil, vector_ef_search: nil, search_non_declarables: nil)
    new(query:, limit:, filter_prefixes:, request_id:, vector_score_threshold:, vector_ef_search:, search_non_declarables:).call
  end

  def self.call_with_diagnostics(query:, limit: 80, filter_prefixes: [], request_id: nil, vector_score_threshold: nil, vector_ef_search: nil, search_non_declarables: nil)
    new(query:, limit:, filter_prefixes:, request_id:, vector_score_threshold:, vector_ef_search:, search_non_declarables:).call_with_diagnostics
  end

  def initialize(query:, limit: 80, filter_prefixes: [], request_id: nil, vector_score_threshold: nil, vector_ef_search: nil, search_non_declarables: nil)
    @query = query
    @limit = limit
    @filter_prefixes = Array(filter_prefixes).compact_blank
    @request_id = request_id
    @vector_score_threshold = vector_score_threshold
    @vector_ef_search = vector_ef_search
    @search_non_declarables = search_non_declarables
  end

  def call
    ranked_rows = apply_score_threshold(fetch_ranked_rows_for_query)
    return [] if ranked_rows.empty?

    build_results(ranked_rows, enforce_eligibility: true)
  end

  def call_with_diagnostics
    ranked_rows = eligible_ranked_rows(fetch_ranked_rows_for_query)
    max_score = ranked_rows.first&.[](:score)&.to_f
    ranked_rows = apply_score_threshold(ranked_rows)
    return Result.new(results: [], max_score:) if ranked_rows.empty?

    Result.new(results: build_results(ranked_rows), max_score:)
  rescue EmbeddingGenerationError
    raise
  rescue StandardError => e
    raise VectorRetrievalError, e.message
  end

private

  def fetch_ranked_rows_for_query
    query_embedding = generate_query_embedding
    vector_literal = "'[#{query_embedding.join(',')}]'::vector"

    fetch_ranked_sids(vector_literal)
  end

  def generate_query_embedding
    embedding = AiUsage::Instrumentation.embedding_api_call(
      event_kind: 'vector_search_query_embedding',
      batch_size: 1,
      model: EmbeddingService::MODEL,
      request_id: @request_id,
    ) { embedding_service.embed(@query, event_kind: 'vector_search_query_embedding') }
    raise EmbeddingGenerationError, 'Embedding response was empty' unless embedding.is_a?(Array) && embedding.any?

    embedding
  rescue StandardError => e
    raise EmbeddingGenerationError, e.message
  end

  def build_results(ranked_rows, enforce_eligibility: false)
    scores_by_sid = ranked_rows.each_with_object({}) { |r, h| h[r[:goods_nomenclature_sid]] = r[:score]&.to_f }
    ordered_sids = ranked_rows.map { |r| r[:goods_nomenclature_sid] }
    gn_by_sid = load_goods_nomenclatures(ordered_sids)
    include_non_declarables = search_non_declarables? if enforce_eligibility

    ordered_sids.filter_map do |sid|
      goods_nomenclature = gn_by_sid[sid]
      next unless goods_nomenclature
      next if enforce_eligibility && !include_non_declarables && !goods_nomenclature.declarable?

      build_result(goods_nomenclature, scores_by_sid[sid])
    end
  end

  def apply_score_threshold(rows)
    threshold = (@vector_score_threshold || AdminConfiguration.integer_value('vector_score_threshold')) / 100.0
    rows.select { |r| r[:score].to_f >= threshold }
  end

  def eligible_ranked_rows(rows)
    return rows if rows.empty? || search_non_declarables?

    sids = rows.map { |row| row[:goods_nomenclature_sid] }
    eligible_sids = GoodsNomenclature
      .actual
      .declarable
      .where(goods_nomenclatures__goods_nomenclature_sid: sids)
      .then { |dataset| apply_filter_prefixes(dataset, Sequel[:goods_nomenclatures][:goods_nomenclature_item_id]) }
      .unordered
      .select_map(Sequel[:goods_nomenclatures][:goods_nomenclature_sid])
      .to_set

    rows.select { |row| eligible_sids.include?(row[:goods_nomenclature_sid]) }
  end

  def fetch_ranked_sids(vector_literal)
    ef_search = @vector_ef_search || AdminConfiguration.integer_value('vector_ef_search')

    db.transaction do
      db.run("SET LOCAL hnsw.ef_search = #{ef_search.to_i}")

      GoodsNomenclatureSelfText
        .vector_search(vector_literal, limit: @limit)
        .then { |dataset| apply_filter_prefixes(dataset, Sequel[:goods_nomenclature][:goods_nomenclature_item_id]) }
        .all
    end
  end

  def load_goods_nomenclatures(sids)
    GoodsNomenclature
      .actual
      .with_leaf_column
      .where(goods_nomenclatures__goods_nomenclature_sid: sids)
      .then { |dataset| apply_filter_prefixes(dataset, Sequel[:goods_nomenclatures][:goods_nomenclature_item_id]) }
      .eager(:goods_nomenclature_descriptions, :goods_nomenclature_self_text, :heading)
      .all
      .index_by(&:goods_nomenclature_sid)
  end

  def apply_filter_prefixes(dataset, column)
    return dataset if @filter_prefixes.empty?

    dataset.where(Sequel.|(*@filter_prefixes.map { |prefix| Sequel.like(column, "#{prefix}%") }))
  end

  def build_result(goods_nomenclature, score)
    self_text = goods_nomenclature.goods_nomenclature_self_text&.self_text
    full_desc = self_text.presence ||
      DescriptionHtmlFormatter.call(goods_nomenclature.raw_classification_description)

    GoodsNomenclatureResult.new(
      id: goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      producline_suffix: goods_nomenclature.producline_suffix,
      goods_nomenclature_class: goods_nomenclature.goods_nomenclature_class,
      description: goods_nomenclature.description_html,
      formatted_description: goods_nomenclature.description_html,
      self_text: self_text,
      classification_description: goods_nomenclature.classification_description,
      full_description: full_desc,
      heading_description: goods_nomenclature.heading&.description_html,
      declarable: goods_nomenclature.respond_to?(:declarable?) ? goods_nomenclature.declarable? : false,
      score: score,
      confidence: nil,
    )
  end

  def search_non_declarables?
    return @search_non_declarables unless @search_non_declarables.nil?

    AdminConfiguration.enabled?('search_non_declarables')
  end

  def embedding_service
    @embedding_service ||= EmbeddingService.new
  end

  def db
    Sequel::Model.db
  end
end
