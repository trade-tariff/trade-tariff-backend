class SearchExpansionDecisionService
  DECIDERS = {
    'v1' => Search::ExpansionDeciders::CasingAndEvidence,
    'v2' => Search::ExpansionDeciders::EvidenceOnly,
  }.freeze

  Result = Data.define(:expand, :reason, :result_count, :max_score) do
    def expand?
      expand
    end
  end

  def self.call(query:, results: nil, request_id: nil)
    new(query:, results:, request_id:).call
  end

  def self.decider_version
    configured_version = AdminConfiguration.option_value('expand_search_decider')
    DECIDERS.key?(configured_version) ? configured_version : 'v1'
  end

  def initialize(query:, results: nil, request_id: nil)
    @query = query.to_s
    @results = Array(results)
    @request_id = request_id
  end

  def call
    decision = expansion_decision

    Search::Instrumentation.query_expansion_decided(
      request_id: request_id,
      query: query,
      expand: decision.expand?,
      reason: decision.reason,
      decider_version:,
      result_count: decision.result_count,
      max_score: decision.max_score,
    )

    decision
  end

private

  attr_reader :query, :results, :request_id

  def expansion_decision
    return result(false, 'disabled') unless AdminConfiguration.enabled?('expand_search_enabled')
    return result(true, 'always_enabled') unless AdminConfiguration.enabled?('expand_search_when_needed_enabled')

    reason = decider.call(query:, results:, max_score:)
    result(reason != 'sufficient_results', reason)
  end

  def max_score
    @max_score ||= results.filter_map { |result| result.score&.to_f }.max
  end

  def decider
    DECIDERS.fetch(decider_version)
  end

  def decider_version
    self.class.decider_version
  end

  def result(expand, reason)
    Result.new(expand:, reason:, result_count: results.size, max_score:)
  end
end
