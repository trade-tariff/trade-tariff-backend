class InteractiveSearchService
  Result = Struct.new(:type, :data, :attempt, :model, :result_limit, keyword_init: true)

  CONFIDENCE_ORDER = %w[strong good possible].freeze
  FINAL_ANSWER_INSTRUCTION = <<~INSTRUCTION.freeze

    IMPORTANT: You have asked the maximum number of questions allowed. Based on the search input, OpenSearch results, and the answers provided so far, you MUST now provide your best answer. Do not ask any more questions. Rank the opensearch results by confidence using the information you have.
  INSTRUCTION

  def initialize(query:, expanded_query:, opensearch_results:, answers: [], request_id: nil)
    @query = query
    @expanded_query = expanded_query
    @opensearch_results = opensearch_results
    @answers = answers || []
    @request_id = request_id
    @attempt = @answers.size + 1
  end

  def call
    return nil if disabled?
    return single_result_answer if single_result?
    return no_results_error if no_results?
    return final_answer if max_questions_reached?

    response = OpenaiClient.call(build_context, model: configured_model)
    parsed = ExtractBottomJson.call(response)

    if parsed['error'].present?
      error_result(parsed['error'])
    elsif parsed['answers'].present?
      answers_result(parsed['answers'])
    elsif has_questions?(parsed)
      questions_result(parsed)
    else
      best_available_answers
    end
  rescue StandardError => e
    Rails.logger.error("InteractiveSearchService error: #{e.message}")
    nil
  end

  class << self
    def call(...)
      new(...).call
    end
  end

  private

  attr_reader :query, :expanded_query, :opensearch_results, :answers, :request_id, :attempt

  def disabled?
    !AdminConfiguration.enabled?('interactive_search_enabled')
  end

  def single_result?
    opensearch_results.size == 1
  end

  def no_results?
    opensearch_results.empty?
  end

  def max_questions_reached?
    answers.size > max_questions
  end

  def max_questions
    AdminConfiguration.integer_value('interactive_search_max_questions')
  end

  def configured_model
    AdminConfiguration.option_value('search_model')
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('search_context')
    config&.value.to_s
  end

  def configured_result_limit
    AdminConfiguration.integer_value('search_result_limit')
  end

  def build_context
    context = configured_context.to_s
    context
      .gsub('%{search_input}', query.to_s)
      .gsub('%{answers_opensearch}', format_opensearch_results.to_s)
      .gsub('%{questions}', format_questions_and_answers.to_s)
  end

  def format_opensearch_results
    results = opensearch_results.map do |result|
      {
        commodity_code: result.goods_nomenclature_item_id,
        description: result.description,
        score: result.score,
      }
    end
    results.to_json
  end

  def format_questions_and_answers
    return '[]' if answers.empty?

    formatted = answers.map.with_index do |qa, index|
      {
        index: index,
        question: qa[:question] || qa['question'],
        answer: qa[:answer] || qa['answer'],
      }
    end
    formatted.to_json
  end

  def valid_commodity_codes
    @valid_commodity_codes ||= opensearch_results.map(&:goods_nomenclature_item_id).to_set
  end

  def filter_hallucinated_codes(ai_answers)
    ai_answers.select do |answer|
      code = answer['commodity_code'] || answer[:commodity_code]
      valid_commodity_codes.include?(code)
    end
  end

  def single_result_answer
    result = opensearch_results.first
    Result.new(
      type: :answers,
      data: [{ commodity_code: result.goods_nomenclature_item_id, confidence: 'strong' }],
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
    )
  end

  def no_results_error
    Result.new(
      type: :error,
      data: { message: 'No search results found' },
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
    )
  end

  def final_answer
    context = build_context + FINAL_ANSWER_INSTRUCTION
    response = OpenaiClient.call(context, model: configured_model)
    parsed = ExtractBottomJson.call(response)

    if parsed['answers'].present?
      answers_result(parsed['answers'])
    else
      best_available_answers
    end
  end

  def best_available_answers
    limit = configured_result_limit
    results_to_process = limit.zero? ? opensearch_results : opensearch_results.first(limit)
    top_results = results_to_process.map.with_index do |result, index|
      confidence = index < 2 ? 'good' : 'possible'
      { commodity_code: result.goods_nomenclature_item_id, confidence: confidence }
    end

    Result.new(
      type: :answers,
      data: top_results,
      attempt: attempt,
      model: configured_model,
      result_limit: limit,
    )
  end

  def error_result(message)
    Result.new(
      type: :error,
      data: { message: message },
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
    )
  end

  def answers_result(ai_answers)
    filtered = filter_hallucinated_codes(ai_answers)
    return best_available_answers if filtered.empty?

    limit = configured_result_limit
    normalized = filtered.map do |answer|
      {
        commodity_code: answer['commodity_code'] || answer[:commodity_code],
        confidence: normalize_confidence(answer['confidence'] || answer[:confidence]),
      }
    end

    sorted = normalized.sort_by { |a| CONFIDENCE_ORDER.index(a[:confidence]) || 99 }
    final_results = limit.zero? ? sorted : sorted.first(limit)

    Result.new(
      type: :answers,
      data: final_results,
      attempt: attempt,
      model: configured_model,
      result_limit: limit,
    )
  end

  def normalize_confidence(confidence)
    return 'possible' if confidence.blank?

    normalized = confidence.to_s.downcase.strip
    CONFIDENCE_ORDER.include?(normalized) ? normalized : 'possible'
  end

  def has_questions?(parsed)
    parsed['questions'].is_a?(Array) && parsed['questions'].any?
  end

  def questions_result(parsed)
    questions = extract_questions(parsed)
    return best_available_answers if questions.empty?

    Result.new(
      type: :questions,
      data: questions.first(1),
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
    )
  end

  def extract_questions(parsed)
    return [] unless parsed['questions'].is_a?(Array)

    parsed['questions'].filter_map do |q|
      case q
      when Hash
        text = q['question']
        options = q['options'].is_a?(Array) ? q['options'].map(&:to_s) : %w[Yes No]
        { question: text, options: options } if text.present?
      when String
        { question: q, options: %w[Yes No] }
      end
    end
  end
end
