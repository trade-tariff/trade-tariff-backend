class HybridRetrievalService
  AllLegsFailed = Class.new(StandardError)
  LegResult = Data.define(:value, :error)
  Result = Data.define(:results, :expanded_query, :source_results)

  def self.call(query:, as_of:, expanded_query: nil, request_id: nil, limit: 30, filter_prefixes: [], iteration: nil)
    new(query:, as_of:, expanded_query:, request_id:, limit:, filter_prefixes:, iteration:).call
  end

  def initialize(query:, as_of:, expanded_query: nil, request_id: nil, limit: 30, filter_prefixes: [], iteration: nil)
    @query = query
    @expanded_query = expanded_query.presence || query
    @as_of = as_of
    @request_id = request_id
    @limit = limit
    @filter_prefixes = Array(filter_prefixes).compact_blank
    @iteration = iteration
  end

  def call
    opensearch_leg, vector_leg = run_concurrent_retrievals
    leg_errors = [opensearch_leg.error, vector_leg.error].compact

    if leg_errors.size == 2
      raise AllLegsFailed, "Hybrid retrieval failed for all legs: #{leg_errors.map(&:message).join('; ')}"
    end

    opensearch_items = opensearch_leg.value&.results || []
    vector_items = vector_leg.value || []

    merged = rrf_merge(opensearch_items, vector_items)
    Search::Instrumentation.retrieval_results_returned(
      request_id: @request_id,
      query: @query,
      effective_query: @expanded_query,
      search_type: 'interactive',
      retrieval_method: 'hybrid',
      stage: 'after_rrf',
      iteration: @iteration,
      results: merged,
    )

    Result.new(results: merged, expanded_query: @expanded_query, source_results: opensearch_items + vector_items)
  end

  private

  def run_concurrent_retrievals
    opensearch_thread = Thread.new { run_leg(:opensearch) }
    vector_thread = Thread.new { run_leg(:vector) }

    [opensearch_thread.value, vector_thread.value]
  end

  def run_leg(leg)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = TimeMachine.at(@as_of) do
      case leg
      when :opensearch
        OpensearchRetrievalService.call(**opensearch_args)
      when :vector
        VectorRetrievalService.call(**vector_args)
      end
    end

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    count = leg == :opensearch ? result&.results&.size || 0 : result&.size || 0

    Search::Instrumentation.retrieval_leg_completed(
      request_id: @request_id, leg: leg, duration_ms: duration_ms, result_count: count, status: 'success',
    )
    Search::Instrumentation.retrieval_results_returned(
      request_id: @request_id,
      query: @query,
      effective_query: @expanded_query,
      search_type: 'interactive',
      retrieval_method: 'hybrid',
      stage: 'before_rrf',
      leg: leg,
      iteration: @iteration,
      results: leg == :opensearch ? result&.results || [] : result || [],
    )

    LegResult.new(value: result, error: nil)
  rescue StandardError => e
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

    Search::Instrumentation.retrieval_leg_completed(
      request_id: @request_id, leg: leg, duration_ms: duration_ms, result_count: 0, status: 'error',
      error_message: e.message
    )

    Rails.logger.error("HybridRetrievalService #{leg} leg failed: #{e.message}")
    LegResult.new(value: nil, error: e)
  end

  def opensearch_args
    args = {
      query: @query,
      expanded_query: @expanded_query,
      as_of: @as_of,
      request_id: @request_id,
      limit: @limit,
    }
    args[:filter_prefixes] = @filter_prefixes if @filter_prefixes.present?
    args
  end

  def vector_args
    args = { query: @expanded_query, limit: @limit }
    args[:filter_prefixes] = @filter_prefixes if @filter_prefixes.present?
    args
  end

  def rrf_merge(opensearch_items, vector_items)
    k = AdminConfiguration.integer_value('rrf_k')
    scores = Hash.new(0.0)
    items_by_sid = {}

    opensearch_items.each_with_index do |item, index|
      sid = item.goods_nomenclature_sid
      rank = index + 1
      scores[sid] += 1.0 / (rank + k)
      items_by_sid[sid] ||= item
    end

    vector_items.each_with_index do |item, index|
      sid = item.goods_nomenclature_sid
      rank = index + 1
      scores[sid] += 1.0 / (rank + k)
      items_by_sid[sid] ||= item
    end

    scores
      .sort_by { |_sid, score| -score }
      .map { |sid, score| build_result(items_by_sid[sid], score) }
  end

  def build_result(item, score)
    GoodsNomenclatureResult.new(
      id: item.id,
      goods_nomenclature_item_id: item.goods_nomenclature_item_id,
      goods_nomenclature_sid: item.goods_nomenclature_sid,
      producline_suffix: item.producline_suffix,
      goods_nomenclature_class: item.goods_nomenclature_class,
      description: item.description,
      formatted_description: item.formatted_description,
      self_text: item.self_text,
      classification_description: item.classification_description,
      full_description: item.full_description,
      heading_description: item.heading_description,
      declarable: item.declarable,
      score: score,
      confidence: nil,
    )
  end
end
