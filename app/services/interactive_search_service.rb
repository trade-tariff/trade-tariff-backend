class InteractiveSearchService
  Result = Data.define(:type, :data, :attempt, :model, :result_limit, :ranking_source) do
    def initialize(type:, data:, attempt:, model:, result_limit:, ranking_source: nil)
      super
    end
  end

  CONFIDENCE_ORDER = %w[strong good possible].freeze
  UNCERTAINTY_OPTION_PATTERNS = [
    /\Ai\s+don'?t\s+know\z/i,
    /\Adon'?t\s+know\z/i,
    /\Anot\s+sure\z/i,
    /\Aunknown\z/i,
    /\Aunsure\z/i,
    /\Acannot\s+determine\z/i,
    %r{\An/?a\z}i,
  ].freeze
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

    response = Search::Instrumentation.api_call(
      request_id: request_id,
      model: configured_model,
      attempt_number: attempt,
      iteration: attempt,
      effective_query: expanded_query,
    ) { OpenaiClient.call(build_context, model: configured_model, reasoning_effort: configured_reasoning_effort) }
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
    Search::Instrumentation.search_failed(
      request_id: request_id,
      error_type: e.class.name,
      error_message: e.message,
      search_type: 'interactive',
    )
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
    answers.size >= max_questions
  end

  def max_questions
    AdminConfiguration.integer_value('interactive_search_max_questions')
  end

  def model_config
    @model_config ||= AdminConfiguration.nested_options_value('search_model')
  end

  def configured_model
    model_config[:selected]
  end

  def configured_reasoning_effort
    model_config[:sub_values]['reasoning_effort']
  end

  def configured_context
    config = AdminConfiguration.classification.by_name('search_context')
    config&.value.to_s
  end

  def configured_result_limit
    AdminConfiguration.integer_value('search_result_limit')
  end

  def build_context
    context = context_with_compressed_notes(configured_context.to_s)
    context
      .gsub('%{search_input}', query.to_s)
      .gsub('%{expanded_query}', expanded_query.to_s)
      .gsub('%{answers_opensearch}', format_opensearch_results.to_s)
      .gsub('%{questions}', format_questions_and_answers.to_s)
  end

  def context_with_compressed_notes(context)
    if context.include?('%{compressed_notes}')
      compressed_note_contexts.any? ? context.gsub('%{compressed_notes}', format_compressed_notes) : remove_compressed_notes_line(context)
    elsif compressed_note_contexts.any?
      context.sub(/^.*%{answers_opensearch}.*$/) do |answers_opensearch_line|
        "Relevant compressed notes: #{format_compressed_notes}\n#{answers_opensearch_line}"
      end
    else
      context
    end
  end

  def remove_compressed_notes_line(context)
    context
      .gsub(/^[^\n]*RELEVANT_COMPRESSED_NOTES[^\n]*\n[^\n]*%\{compressed_notes\}[^\n]*\n[^\n]*END RELEVANT_COMPRESSED_NOTES[^\n]*\n?/, '')
      .gsub(/^.*%{compressed_notes}.*$\n?/, '')
  end

  def format_opensearch_results
    results = opensearch_results.map do |result|
      formatted_result = {
        commodity_code: result.goods_nomenclature_item_id,
        description: result.full_description.presence || result.description,
        score: result.score,
      }
      note_key = selected_compressed_note_keys_by_item_id[result.goods_nomenclature_item_id]
      formatted_result[:compressed_note_refs] = [compressed_note_ref(note_key)] if note_key
      formatted_result
    end
    results.to_json
  end

  def format_compressed_notes = compressed_note_contexts.to_json

  def compressed_notes_by_item_id
    return {} unless AdminConfiguration.enabled?('search_compressed_notes_enabled')

    @compressed_notes_by_item_id ||= begin
      item_ids = opensearch_results.map(&:goods_nomenclature_item_id).compact_blank.uniq
      TariffKnowledge::CompressedNote.usable_for_search
        .by_item_ids(item_ids)
        .order(Sequel.desc(:generated_at), Sequel.desc(:updated_at))
        .each_with_object({}) do |note, by_item_id|
        by_item_id[note.goods_nomenclature_item_id] ||= note
      end
    end
  end

  def compressed_note_contexts
    return @compressed_note_contexts if defined?(@compressed_note_contexts)

    @compressed_note_contexts = selected_compressed_note_contexts.map do |context|
      { note_ref: compressed_note_ref(context[:key]), commodity_codes: context[:commodity_codes], fragments: context[:fragments] }
    end
  end

  def selected_compressed_note_keys_by_item_id
    @selected_compressed_note_keys_by_item_id ||= begin
      selected_note_keys = selected_compressed_note_contexts.pluck(:key).to_set

      compressed_notes_by_item_id.each_with_object({}) do |(item_id, note), by_item_id|
        by_item_id[item_id] = note.context_hash if selected_note_keys.include?(note.context_hash)
      end
    end
  end

  def selected_compressed_note_contexts = @selected_compressed_note_contexts ||= TariffKnowledge::RelevantNoteFragmentSelector.call(query:, search_results: opensearch_results, notes_by_item_id: compressed_notes_by_item_id)

  def compressed_note_ref(compressed_note_key)
    @compressed_note_refs ||= {}
    @compressed_note_refs[compressed_note_key] ||= "compressed_note_#{@compressed_note_refs.size + 1}"
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
    data = [{ commodity_code: result.goods_nomenclature_item_id, confidence: 'strong' }]

    emit_answer_returned(data)

    Result.new(
      type: :answers,
      data: data,
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
      ranking_source: 'single_result',
    )
  end

  def no_results_error
    Result.new(
      type: :error,
      data: { message: 'No search results found' },
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
      ranking_source: 'no_results',
    )
  end

  def final_answer
    context = build_context + FINAL_ANSWER_INSTRUCTION
    response = Search::Instrumentation.api_call(
      request_id: request_id,
      model: configured_model,
      attempt_number: attempt,
      iteration: attempt,
      effective_query: expanded_query,
    ) { OpenaiClient.call(context, model: configured_model, reasoning_effort: configured_reasoning_effort) }
    parsed = ExtractBottomJson.call(response)

    if parsed['answers'].present?
      answers_result(parsed['answers'])
    elsif parsed['error'].present?
      error_result(parsed['error'])
    else
      best_available_answers
    end
  end

  def best_available_answers(ranking_source: 'best_available_fallback')
    limit = configured_result_limit
    results_to_process = limit.zero? ? opensearch_results : opensearch_results.first(limit)
    top_results = results_to_process.map.with_index do |result, index|
      confidence = index < 2 ? 'good' : 'possible'
      { commodity_code: result.goods_nomenclature_item_id, confidence: confidence }
    end

    emit_answer_returned(top_results)

    Result.new(
      type: :answers,
      data: top_results,
      attempt: attempt,
      model: configured_model,
      result_limit: limit,
      ranking_source: ranking_source,
    )
  end

  def error_result(message)
    Result.new(
      type: :error,
      data: { message: message },
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
      ranking_source: 'model_error',
    )
  end

  def answers_result(ai_answers)
    filtered = filter_hallucinated_codes(ai_answers)
    return best_available_answers(ranking_source: 'filtered_hallucinated_answers') if filtered.empty?

    limit = configured_result_limit
    normalized = filtered.map do |answer|
      {
        commodity_code: answer['commodity_code'] || answer[:commodity_code],
        confidence: normalize_confidence(answer['confidence'] || answer[:confidence]),
      }
    end

    sorted = normalized.sort_by { |a| CONFIDENCE_ORDER.index(a[:confidence]) || 99 }
    final_results = limit.zero? ? sorted : sorted.first(limit)

    emit_answer_returned(final_results)

    Result.new(
      type: :answers,
      data: final_results,
      attempt: attempt,
      model: configured_model,
      result_limit: limit,
      ranking_source: 'model_answers',
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

    Search::Instrumentation.question_returned(
      request_id: request_id,
      question_count: questions.size,
      attempt_number: attempt,
      iteration: attempt,
      effective_query: expanded_query,
      questions: questions,
    )

    Result.new(
      type: :questions,
      data: questions.first(1),
      attempt: attempt,
      model: configured_model,
      result_limit: configured_result_limit,
      ranking_source: 'model_questions',
    )
  end

  def extract_questions(parsed)
    return [] unless parsed['questions'].is_a?(Array)

    parsed['questions'].filter_map do |q|
      case q
      when Hash
        text = q['question']
        options = q['options'].is_a?(Array) ? concrete_options(q['options']) : %w[Yes No]
        { question: text, options: options } if text.present? && options.any?
      when String
        { question: q, options: %w[Yes No] }
      end
    end
  end

  def concrete_options(options)
    options.map(&:to_s).reject do |option|
      UNCERTAINTY_OPTION_PATTERNS.any? { |pattern| pattern.match?(option.strip) }
    end
  end

  def emit_answer_returned(answers_data)
    confidence_levels = answers_data.map { |a| a[:confidence] }.tally
    Search::Instrumentation.answer_returned(
      request_id: request_id,
      answer_count: answers_data.size,
      confidence_levels: confidence_levels,
      attempt_number: attempt,
      iteration: attempt,
      effective_query: expanded_query,
      answers: answers_data,
    )
  end
end
