class SearchInstrumentationService
  MATCH_TYPES = %i[goods_nomenclature_match reference_match].freeze
  LEVELS = %w[sections chapters headings commodities].freeze

  def self.log_search_suggestions_results(query, results)
    results_count = results[:data].size
    results_zero = results_count.nil? || results_count.zero?
    query_length = query.present? ? query.length : 0

    log_entry = {
      timestamp: Time.zone.now.utc.iso8601,
      level: 'INFO',
      service: 'api/v2/search_suggestions',
      message: 'Search Suggestion Request',
      search_query: query,
      query_length: query_length,
      result_count: results_count,
      result_zero: results_zero,
    }

    Rails.logger.info(log_entry.to_json)
  end

  def self.log_search_results(query, results)
    results_type = results[:data][:type]
    attributes = results[:data][:attributes]

    max_score = MATCH_TYPES.product(LEVELS).map { |group|
      match, level = group
      attributes&.dig(match)&.dig(level)&.first&.dig('_score') || 0
    }.max

    results_count = MATCH_TYPES.product(LEVELS).map { |group|
      match, level = group
      attributes&.dig(match)&.dig(level)&.size || 0
    }.sum

    query_length = query.present? ? query.length : 0

    log_entry = {
      timestamp: Time.zone.now.utc.iso8601,
      level: 'INFO',
      service: 'api/v2/search',
      message: 'Search Request',
      search_query: query,
      query_length: query_length,
      results_type: results_type,
      max_score: max_score,
      result_count: results_count,
      result_zero: results_count.zero?,
    }

    Rails.logger.info(log_entry.to_json)
  end
end
