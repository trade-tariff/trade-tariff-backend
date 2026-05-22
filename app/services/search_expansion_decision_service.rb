class SearchExpansionDecisionService
  NOISE_TAGS = Search::GoodsNomenclatureQuery::NOISE_TAGS
  NON_WORD_TOKEN_PATTERN = /\b[A-Z]{2,6}\b/

  Result = Data.define(:expand, :reason, :result_count, :max_score) do
    def expand?
      expand
    end
  end

  def self.call(query:, results: nil, request_id: nil)
    new(query:, results:, request_id:).call
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
    return result(true, 'non_word_token') if non_word_token?
    return result(true, 'no_significant_word_parts') if no_significant_word_parts?
    return result(true, 'low_result_count') if low_result_count?
    return result(true, 'low_max_score') if low_max_score?

    result(false, 'sufficient_results')
  end

  def non_word_token?
    query.scan(NON_WORD_TOKEN_PATTERN).any?
  end

  def no_significant_word_parts?
    tagged_words = tag_words
    return false if tagged_words.empty?

    tagged_words.none? { |_word, tag| tag.present? && !NOISE_TAGS.include?(tag) }
  end

  def tag_words
    Search::GoodsNomenclatureQuery.tagger.get_readable(query).split.filter_map do |token|
      word, tag = token.split('/')
      next if word.blank? || word.match?(/\A\W+\z/)

      [word, tag&.downcase]
    end
  end

  def low_result_count?
    results.size < AdminConfiguration.integer_value('expand_search_min_results')
  end

  def low_max_score?
    return false if max_score.nil?

    max_score < AdminConfiguration.integer_value('expand_search_min_score')
  end

  def max_score
    @max_score ||= results.filter_map { |result| result.score&.to_f }.max
  end

  def result(expand, reason)
    Result.new(expand:, reason:, result_count: results.size, max_score:)
  end
end
