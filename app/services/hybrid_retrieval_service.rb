class HybridRetrievalService
  Result = Struct.new(:results, :expanded_query, keyword_init: true)

  def self.call(query:, as_of:, request_id: nil, limit: 30)
    new(query:, as_of:, request_id:, limit:).call
  end

  def initialize(query:, as_of:, request_id: nil, limit: 30)
    @query = query
    @as_of = as_of
    @request_id = request_id
    @limit = limit
  end

  def call
    opensearch_result, vector_results = run_concurrent_retrievals

    opensearch_items = opensearch_result&.results || []
    vector_items = vector_results || []
    expanded_query = opensearch_result&.expanded_query

    merged = rrf_merge(opensearch_items, vector_items)

    Result.new(results: merged, expanded_query: expanded_query)
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
        OpensearchRetrievalService.call(
          query: @query, as_of: @as_of, request_id: @request_id, limit: @limit,
        )
      when :vector
        VectorRetrievalService.call(query: @query, limit: @limit)
      end
    end

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    count = leg == :opensearch ? result&.results&.size || 0 : result&.size || 0

    Search::Instrumentation.retrieval_leg_completed(
      request_id: @request_id, leg: leg, duration_ms: duration_ms, result_count: count, status: 'success',
    )

    result
  rescue StandardError => e
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

    Search::Instrumentation.retrieval_leg_completed(
      request_id: @request_id, leg: leg, duration_ms: duration_ms, result_count: 0, status: 'error',
    )

    Rails.logger.error("HybridRetrievalService #{leg} leg failed: #{e.message}")
    nil
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
    OpenStruct.new(
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
