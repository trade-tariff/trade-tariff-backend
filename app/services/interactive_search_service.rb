class InteractiveSearchService
  Result = Struct.new(:type, :data, :attempt, :model, keyword_init: true)

  CONFIDENCE_ORDER = %w[strong good possible].freeze
  QUESTIONS_ALIASES = %w[questions extra_questions].freeze
  QUESTION_ALIASES = %w[question extra_question text].freeze
  OPTIONS_ALIASES = %w[options option_choices choices].freeze

  def initialize(query:, expanded_query:, opensearch_results:, answers: [], request_id: nil)
    @query = query
    @expanded_query = expanded_query
    @opensearch_results = opensearch_results
    @answers = answers || []
    @request_id = request_id
    @attempt = answers.size + 1
  end

  def call
    return nil if disabled?
    return single_result_answer if single_result?
    return no_results_error if no_results?
    return best_available_answers if max_attempts_reached?

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
    config = AdminConfiguration.classification.by_name('interactive_search_enabled')
    config.present? && config.value == false
  end

  def single_result?
    opensearch_results.size == 1
  end

  def no_results?
    opensearch_results.empty?
  end

  def max_attempts_reached?
    attempt > max_attempts
  end

  def max_attempts
    TradeTariffBackend.interactive_search_max_attempts
  end

  def configured_model
    config = AdminConfiguration.classification.by_name('search_model')
    return TradeTariffBackend.ai_model if config.nil?

    config.value.is_a?(Hash) ? config.value['selected'] : config.value.presence || TradeTariffBackend.ai_model
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('search_context')
    config&.value.presence || I18n.t('contexts.interactive_search.instructions')
  end

  def build_context
    configured_context
      .gsub('%{search_input}', query.to_s)
      .gsub('%{answers_opensearch}', format_opensearch_results)
      .gsub('%{questions}', format_questions_and_answers)
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
    )
  end

  def no_results_error
    Result.new(
      type: :error,
      data: { message: 'No search results found' },
      attempt: attempt,
      model: configured_model,
    )
  end

  def best_available_answers
    top_results = opensearch_results.first(5).map.with_index do |result, index|
      confidence = index < 2 ? 'good' : 'possible'
      { commodity_code: result.goods_nomenclature_item_id, confidence: confidence }
    end

    Result.new(
      type: :answers,
      data: top_results,
      attempt: attempt,
      model: configured_model,
    )
  end

  def error_result(message)
    Result.new(
      type: :error,
      data: { message: message },
      attempt: attempt,
      model: configured_model,
    )
  end

  def answers_result(ai_answers)
    filtered = filter_hallucinated_codes(ai_answers)
    return best_available_answers if filtered.empty?

    normalized = filtered.map do |answer|
      {
        commodity_code: answer['commodity_code'] || answer[:commodity_code],
        confidence: normalize_confidence(answer['confidence'] || answer[:confidence]),
      }
    end

    sorted = normalized.sort_by { |a| CONFIDENCE_ORDER.index(a[:confidence]) || 99 }

    Result.new(
      type: :answers,
      data: sorted.first(5),
      attempt: attempt,
      model: configured_model,
    )
  end

  def normalize_confidence(confidence)
    return 'possible' if confidence.blank?

    normalized = confidence.to_s.downcase.strip
    CONFIDENCE_ORDER.include?(normalized) ? normalized : 'possible'
  end

  def has_questions?(parsed)
    QUESTIONS_ALIASES.any? { |key| parsed[key].is_a?(Array) && parsed[key].any? }
  end

  def questions_result(parsed)
    questions = extract_questions(parsed)
    return best_available_answers if questions.empty?

    Result.new(
      type: :questions,
      data: questions.first(1),
      attempt: attempt,
      model: configured_model,
    )
  end

  def extract_questions(parsed)
    questions = []

    QUESTIONS_ALIASES.each do |questions_key|
      next unless parsed[questions_key].is_a?(Array)

      parsed[questions_key].each do |q|
        case q
        when Hash
          text = extract_question_text(q)
          options = extract_options(q)
          questions << { question: text, options: options } if text.present?
        when String
          questions << { question: q, options: %w[Yes No] }
        end
      end
    end

    questions
  end

  def extract_question_text(question_hash)
    QUESTION_ALIASES.each do |key|
      return question_hash[key] if question_hash[key].present?
    end
    nil
  end

  def extract_options(question_hash)
    OPTIONS_ALIASES.each do |key|
      if question_hash[key].is_a?(Array) && question_hash[key].any?
        return question_hash[key].map(&:to_s)
      end
    end
    %w[Yes No]
  end
end
