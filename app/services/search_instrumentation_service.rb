class SearchInstrumentationService
  MATCH_TYPES = %i[goods_nomenclature_match reference_match].freeze
  LEVELS = %w[sections chapters headings commodities].freeze

  attr_reader :search_query

  def initialize(search_query)
    @search_query = search_query
  end

  def log_search_suggestions_results(results)
    result_count = results[:data].size
    result_zero = result_count.nil? || result_count.zero?

    log_entry = {
      timestamp: Time.zone.now.utc.iso8601,
      level: 'INFO',
      service: 'api/v2/search_suggestions',
      message: 'Search Suggestion Request',
      search_query:,
      query_length:,
      result_count:,
      result_zero:,
    }

    Rails.logger.info(log_entry.to_json)
  end

  def log_search_results(results)
    results_type = results[:data][:type]
    attributes = results[:data][:attributes]
    result_count = count_results(attributes, results_type)

    log_entry = {
      timestamp: Time.zone.now.utc.iso8601,
      level: 'INFO',
      service: 'api/v2/search',
      message: 'Search Request',
      search_query:,
      query_length:,
      results_type:,
      max_score: max_score(attributes),
      result_count:,
      result_zero: result_count.zero?,
    }

    Rails.logger.info(log_entry.to_json)
  end

  private

  def max_score(attributes)
    MATCH_TYPES.product(LEVELS).map { |group|
      match, level = group
      attributes&.dig(match)&.dig(level)&.first&.dig('_score') || 0
    }.max
  end

  def count_results(attributes, results_type)
    MATCH_TYPES.product(LEVELS).map { |group|
      match, level = group
      attributes&.dig(match)&.dig(level)&.size || 0
    }.sum
  end

  def query_length
    search_query.present? ? search_query.length : 0
  end
end
