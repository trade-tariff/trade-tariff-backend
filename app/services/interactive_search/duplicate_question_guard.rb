module InteractiveSearch
  class DuplicateQuestionGuard
    Result = Data.define(:allowed?, :duplicate?, :suspicious, :signals, :reason, :duplicate_of_question, :duplicate_of_answer)

    BROAD_ITEM_IDENTITY_STEMS = [
      /\Awhat\s+(?:best\s+)?describes\b/i,
      /\Awhat\s+(?:type|category)\s+of\s+(?:goods|item|product)\b/i,
      /\Awhich\s+(?:of\s+these\s+)?(?:best\s+)?describes\b/i,
      /\Awhich\s+(?:of\s+these\s+)?(?:best\s+)?matches\b/i,
      /\Awhich\s+category\s+(?:does|do)\b/i,
    ].freeze
    NORMALIZE_PATTERN = /[^a-z0-9]+/
    QUESTION_STOP_WORDS = %w[
      a an and are as at be best being by can does for from goods has have how in import imported importing is item of on or that the these this to what when where which with
    ].to_set.freeze

    def self.call(...)
      new(...).call
    end

    def initialize(query:, effective_query:, answers:, candidate_question:, request_id:, attempt_number:)
      @query = query
      @effective_query = effective_query
      @answers = Array(answers)
      @candidate_question = candidate_question || {}
      @request_id = request_id
      @attempt_number = attempt_number
    end

    def call
      return allowed_result(suspicious: false, reason: 'guard_disabled') unless enabled?

      signals = suspicion_signals
      return allowed_result(suspicious: false, signals: signals, reason: 'not_suspicious') if signals.empty?

      validation = validate_semantically
      return allowed_result(suspicious: true, signals: signals, reason: 'validator_unparseable') unless usable_validation?(validation)
      if validation['duplicate'] == true
        return duplicate_result(
          signals: signals,
          reason: validation['reason'],
          duplicate_of_question: validation['duplicate_of_question'],
          duplicate_of_answer: validation['duplicate_of_answer'],
        )
      end

      allowed_result(suspicious: true, signals: signals, reason: validation['reason'])
    end

    private

    attr_reader :query, :effective_query, :answers, :candidate_question, :request_id, :attempt_number

    def enabled?
      AdminConfiguration.enabled?('interactive_search_duplicate_question_guard_enabled')
    end

    def suspicion_signals
      signals = []
      signals << 'repeated_question_text' if repeated_question_text?
      signals << 'similar_question_text' if similar_question_text?
      signals << 'repeated_selected_answer' if repeated_selected_answer?
      signals << 'substantial_option_overlap' if substantial_option_overlap?
      signals << 'broad_item_identity_stem' if repeated_broad_item_identity_stem?
      signals
    end

    def repeated_question_text?
      normalized_candidate_question = normalize(candidate_question_text)
      return false if normalized_candidate_question.blank?

      answered_questions.any? { |question| normalize(question) == normalized_candidate_question }
    end

    def similar_question_text?
      candidate_tokens = question_tokens(candidate_question_text)
      return false if candidate_tokens.empty?

      answered_questions.any? do |question|
        previous_tokens = question_tokens(question)
        next false if previous_tokens.empty?
        next true if candidate_tokens == previous_tokens
        next true if candidate_tokens.subset?(previous_tokens) || previous_tokens.subset?(candidate_tokens)
        next false if candidate_tokens.size < 3 || previous_tokens.size < 3

        (candidate_tokens & previous_tokens).size / [candidate_tokens.size, previous_tokens.size].min.to_f >= 0.8
      end
    end

    def repeated_selected_answer?
      candidate_option_values.any? do |candidate_option|
        answered_values.any? { |answer| normalize(candidate_option) == normalize(answer) }
      end
    end

    def repeated_broad_item_identity_stem?
      return false unless broad_item_identity_stem?(candidate_question_text)

      answered_questions.any? { |question| broad_item_identity_stem?(question) }
    end

    def substantial_option_overlap?
      candidate_options = candidate_option_values.map { |option| normalize(option) }.reject(&:blank?)
      return false if candidate_options.empty?

      previous_options = answers.flat_map { |answer| option_values(answer[:options] || answer['options']) }
                                .map { |option| normalize(option) }
                                .reject(&:blank?)
      return false if previous_options.empty?

      overlap_count = (candidate_options & previous_options).size
      overlap_count >= 2 || overlap_count >= (candidate_options.size / 2.0).ceil
    end

    def validate_semantically
      response = Search::Instrumentation.api_call(
        request_id: request_id,
        model: model_config[:selected],
        attempt_number: attempt_number,
        iteration: attempt_number,
        effective_query: effective_query,
        operation: 'duplicate_question_validator',
        emit_search_failed: false,
      ) do
        OpenaiClient.call(
          validator_prompt,
          model: model_config[:selected],
          reasoning_effort: model_config[:sub_values]['reasoning_effort'],
        )
      end
      parsed = ExtractBottomJson.call(response)
      parsed.is_a?(Hash) ? parsed : nil
    rescue StandardError
      nil
    end

    def usable_validation?(validation)
      validation.is_a?(Hash) && [true, false].include?(validation['duplicate'])
    end

    def validator_prompt
      configured_context
        .gsub('%{search_query}', query.to_s)
        .gsub('%{effective_query}', effective_query.to_s)
        .gsub('%{previous_answers}', previous_answers_json)
        .gsub('%{candidate_question}', candidate_question_json)
    end

    def model_config
      @model_config ||= AdminConfiguration.nested_options_value('interactive_search_duplicate_question_guard_model')
    end

    def configured_context
      config = AdminConfiguration.classification.by_name('interactive_search_duplicate_question_guard_context')
      config&.value.to_s
    end

    def previous_answers_json
      answers.map { |answer| { question: answer[:question] || answer['question'], answer: answer[:answer] || answer['answer'] } }.to_json
    end

    def candidate_question_json
      {
        question: candidate_question_text,
        options: candidate_option_values,
      }.to_json
    end

    def broad_item_identity_stem?(text)
      BROAD_ITEM_IDENTITY_STEMS.any? { |pattern| pattern.match?(text.to_s.strip) }
    end

    def answered_values
      answers.filter_map { |answer| answer[:answer] || answer['answer'] }
    end

    def answered_questions
      answers.filter_map { |answer| answer[:question] || answer['question'] }
    end

    def candidate_question_text
      candidate_question[:question] || candidate_question['question']
    end

    def candidate_option_values
      option_values(candidate_question[:options] || candidate_question['options'])
    end

    def option_values(value)
      case value
      when String
        parsed = JSON.parse(value)
        parsed.is_a?(Array) ? parsed.map(&:to_s) : []
      when Array
        value.map(&:to_s)
      else
        []
      end
    rescue JSON::ParserError
      []
    end

    def normalize(value)
      value.to_s.downcase.gsub(NORMALIZE_PATTERN, ' ').squish
    end

    def question_tokens(value)
      normalize(value)
        .split
        .reject { |token| QUESTION_STOP_WORDS.include?(token) }
        .to_set
    end

    def allowed_result(suspicious:, reason:, signals: [])
      build_result(
        allowed: true,
        duplicate: false,
        suspicious: suspicious,
        signals: signals,
        reason: reason,
      )
    end

    def duplicate_result(signals:, reason:, duplicate_of_question:, duplicate_of_answer:)
      build_result(
        allowed: false,
        duplicate: true,
        suspicious: true,
        signals: signals,
        reason: reason.presence || 'duplicate_question',
        duplicate_of_question: duplicate_of_question,
        duplicate_of_answer: duplicate_of_answer,
      )
    end

    def build_result(allowed:, duplicate:, suspicious:, signals:, reason:, duplicate_of_question: nil, duplicate_of_answer: nil)
      Result.new(
        allowed?: allowed,
        duplicate?: duplicate,
        suspicious: suspicious,
        signals: signals,
        reason: reason,
        duplicate_of_question: duplicate_of_question,
        duplicate_of_answer: duplicate_of_answer,
      ).tap do |result|
        Search::Instrumentation.duplicate_question_guard_checked(
          request_id: request_id,
          attempt_number: attempt_number,
          iteration: attempt_number,
          effective_query: effective_query,
          allowed: result.allowed?,
          duplicate: result.duplicate?,
          suspicious: result.suspicious,
          signals: result.signals,
          reason: result.reason,
          duplicate_of_question: result.duplicate_of_question,
          duplicate_of_answer: result.duplicate_of_answer,
        )
      end
    end
  end
end
