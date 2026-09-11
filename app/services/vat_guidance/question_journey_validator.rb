module VatGuidance
  class QuestionJourneyValidator
    Result = Data.define(:journey_id, :valid, :errors) do
      def valid? = valid

      def as_json
        { 'journey_id' => journey_id, 'valid' => valid, 'errors' => errors }
      end
    end

    FORBIDDEN_TRADER_LABELS = /\b(undecided|unknown|fall[ -]?through|manual review)\b/i
    RATE_KEY = QuestionJourneyContract::RATE_KEY
    RATE_VALUE = QuestionJourneyContract::RATE_VALUE
    MAX_QUESTIONS = 100
    MAX_OUTCOMES = 100
    MAX_EXCLUSIONS = 100
    MAX_FALLTHROUGH_TARGETS = 20
    REQUIRED_COMPOSER = 'AI-1146'.freeze
    MAX_GRAPH_VISITS = 10_000
    MAX_ID_LENGTH = 200
    MAX_TEXT_LENGTH = 20_000
    NOTICE_BY_GUIDE_KEY = {
      'vat-notice-701-23' => '701/23',
      'vat-notice-701-14' => '701/14',
      'vat-notice-709-1' => '709/1',
    }.freeze
    JOURNEY_KEYS = %w[
      journey_id
      source_packet_id
      scope
      composition_required
      root_question_id
      questions
      outcomes
      exclusions
      comparison_role
      fallthrough_targets
      relief_rule_ids
    ].freeze
    REQUIRED_JOURNEY_KEYS = (JOURNEY_KEYS - %w[comparison_role]).freeze
    NOTICE_SCOPE_KEYS = %w[type notice_number label].freeze
    COMMODITY_SCOPE_KEYS = %w[type chapter commodity_code label].freeze
    QUESTION_KEYS = %w[id prompt evidence answers].freeze
    ANSWER_KEYS = %w[id label next relief_disposition].freeze
    TRANSITION_KEYS = %w[type id trader_visible reason].freeze
    OUTCOME_KEYS = %w[id treatment basis evidence relief_question_ids].freeze
    EVIDENCE_KEYS = %w[quote node_id guide_key section_key].freeze
    EXCLUSION_KEYS = %w[id reason evidence].freeze
    FALLTHROUGH_TARGET_KEYS = %w[id resolution required_composer].freeze

    def initialize(journey, packet)
      @errors = []
      @journey = normalize_hash(journey, 'journey')
      @packet = normalize_hash(packet, 'packet')
    end

    def call
      validate_identity
      validate_closed_schema
      validate_nodes
      validate_graph if errors.empty?
      Result.new(journey_id: journey['journey_id'], valid: errors.empty?, errors: errors)
    end

  private

    attr_reader :journey, :packet, :errors

    def validate_identity
      error('journey_id must be a bounded, present string') unless valid_id?(journey['journey_id'])
      error('source_packet_id must be a bounded, present string') unless valid_id?(journey['source_packet_id'])
      error('root_question_id must be a bounded, present string') unless valid_id?(journey['root_question_id'])
      unless journey['source_packet_id'] == packet['packet_id']
        error('source_packet_id does not match the supplied context packet')
        return
      end

      validate_scope
    end

    def validate_scope
      scope = journey['scope']
      unless scope.is_a?(Hash)
        error('scope must be an object')
        return
      end

      source = packet['source']
      unless source.is_a?(Hash)
        error('packet source must be an object')
        return
      end

      if source['node_type'] == 'commodity'
        validate_exact_scope_keys(scope, COMMODITY_SCOPE_KEYS, 'commodity')
        error('commodity packet requires commodity scope') unless scope['type'] == 'commodity'
        %w[chapter commodity_code].each do |key|
          error("scope #{key} does not match packet source") unless scope[key] == source[key]
        end
      else
        validate_exact_scope_keys(scope, NOTICE_SCOPE_KEYS, 'notice')
        error('section packet requires notice scope') unless scope['type'] == 'notice'
        expected_notice = NOTICE_BY_GUIDE_KEY[source['guide_key']]
        error('scope notice_number does not match packet source') unless scope['notice_number'] == expected_notice
      end
      error('scope label does not match packet source') unless scope['label'] == source['heading']
    end

    def validate_exact_scope_keys(scope, expected_keys, scope_type)
      missing = expected_keys - scope.keys
      unknown = scope.keys - expected_keys
      error("#{scope_type} scope has missing fields: #{missing.join(', ')}") if missing.any?
      error("#{scope_type} scope has unknown fields: #{unknown.join(', ')}") if unknown.any?
    end

    def validate_closed_schema
      validate_keys(journey, JOURNEY_KEYS, 'journey')
      validate_required_keys(journey, REQUIRED_JOURNEY_KEYS, 'journey')
      unless [true, false].include?(journey['composition_required'])
        error('composition_required must be true or false')
      end
      questions.each do |question|
        next unless question.is_a?(Hash)

        validate_keys(question, QUESTION_KEYS, "question #{question['id']}")
        validate_keys(question['evidence'], EVIDENCE_KEYS, "question #{question['id']} evidence") if question['evidence'].is_a?(Hash)
        Array(question['answers']).each do |answer|
          next unless answer.is_a?(Hash)

          validate_keys(answer, ANSWER_KEYS, "question #{question['id']} answer")
          if answer['next'].is_a?(Hash)
            transition_keys = answer['next']['type'] == 'fallthrough' ? TRANSITION_KEYS : %w[type id]
            validate_keys(answer['next'], transition_keys, "question #{question['id']} transition")
          end
        end
      end
      outcomes.each do |outcome|
        next unless outcome.is_a?(Hash)

        validate_keys(outcome, OUTCOME_KEYS, "outcome #{outcome['id']}")
        validate_keys(outcome['evidence'], EVIDENCE_KEYS, "outcome #{outcome['id']} evidence") if outcome['evidence'].is_a?(Hash)
      end
      exclusions.each do |exclusion|
        next unless exclusion.is_a?(Hash)

        validate_keys(exclusion, EXCLUSION_KEYS, "exclusion #{exclusion['id']}")
        validate_keys(exclusion['evidence'], EVIDENCE_KEYS, "exclusion #{exclusion['id']} evidence") if exclusion['evidence'].is_a?(Hash)
      end
      fallthrough_targets.each do |target|
        validate_keys(target, FALLTHROUGH_TARGET_KEYS, 'fallthrough target') if target.is_a?(Hash)
      end
      validate_no_rate_keys(journey)
    end

    def validate_nodes
      validate_unique_ids
      validate_fallthrough_targets
      relief_rule_ids
      questions.each { |question| validate_question(question) }
      outcomes.each { |outcome| validate_outcome(outcome) }
      exclusions.each { |exclusion| validate_exclusion(exclusion) }
    end

    def validate_unique_ids
      ids = questions.grep(Hash).pluck('id') + outcomes.grep(Hash).pluck('id')
      duplicates = ids.tally.select { |_id, count| count > 1 }.keys
      error("duplicate node ids: #{duplicates.join(', ')}") if duplicates.any?
      error("too many questions (maximum #{MAX_QUESTIONS})") if questions.size > MAX_QUESTIONS
      error("too many outcomes (maximum #{MAX_OUTCOMES})") if outcomes.size > MAX_OUTCOMES
      error("too many exclusions (maximum #{MAX_EXCLUSIONS})") if exclusions.size > MAX_EXCLUSIONS
    end

    def validate_fallthrough_targets
      error("too many fallthrough targets (maximum #{MAX_FALLTHROUGH_TARGETS})") if fallthrough_targets.size > MAX_FALLTHROUGH_TARGETS
      ids = fallthrough_targets.grep(Hash).pluck('id')
      error('fallthrough target ids must be bounded, present strings') unless ids.all? { |id| valid_id?(id) }
      error('fallthrough target ids must be unique') if ids.compact.uniq.size != ids.size
      fallthrough_targets_by_id
    end

    def validate_question(question)
      unless question.is_a?(Hash)
        error('each question must be an object')
        return
      end

      id = question['id']
      error('question id must be a bounded, present string') unless valid_id?(id)
      error("question #{id} prompt must be a present string") unless present_string?(question['prompt'])
      validate_evidence(question['evidence'], "question #{id}")

      unless question['answers'].is_a?(Array)
        error("question #{id} answers must be an array")
        return
      end

      answers = question['answers']
      error("question #{id} must have at least two answers") if answers.size < 2
      answer_ids = answers.grep(Hash).pluck('id')
      error("question #{id} answer must be an object") if answers.any? { |answer| !answer.is_a?(Hash) }
      error("question #{id} has duplicate answer ids") if answer_ids.compact.uniq.size != answer_ids.size

      answers.each do |answer|
        unless answer.is_a?(Hash)
          next
        end

        error("question #{id} answer id must be a bounded, present string") unless valid_id?(answer['id'])
        label = answer['label']
        error("question #{id} answer label must be a present string") unless present_string?(label)
        label = label.to_s
        error("question #{id} exposes an internal/non-terminal state") if label.match?(FORBIDDEN_TRADER_LABELS)
        if answer['relief_disposition'].present? && !%w[declined qualified].include?(answer['relief_disposition'])
          error("question #{id} answer has invalid relief_disposition")
        end
        validate_transition(answer['next'], "question #{id} answer #{answer['id']}", answer)
      end
    end

    def validate_transition(transition, location, answer)
      unless transition.is_a?(Hash) && QuestionJourneyContract::NEXT_TYPES.include?(transition['type'])
        error("#{location} must lead to a question, outcome, or internal fallthrough")
        return
      end

      error("#{location} target id must be a bounded, present string") unless valid_id?(transition['id'])
      return unless transition['type'] == 'fallthrough'

      error("#{location} fallthrough must not be trader-visible") unless transition['trader_visible'] == false
      error("#{location} fallthrough reason must be a present string") unless present_string?(transition['reason'])
      unless answer['relief_disposition'] == 'declined'
        error("#{location} fallthrough must declare relief_disposition declined")
      end
      error("#{location} fallthrough target is not declared") unless fallthrough_targets_by_id.key?(transition['id'])
    end

    def validate_outcome(outcome)
      unless outcome.is_a?(Hash)
        error('each outcome must be an object')
        return
      end

      id = outcome['id']
      treatment = outcome['treatment']
      error('outcome id must be a bounded, present string') unless valid_id?(id)
      error("outcome #{id} has invalid treatment #{treatment.inspect}") unless QuestionJourneyContract::TREATMENTS.key?(treatment)
      error("outcome #{id} has invalid basis #{outcome['basis'].inspect}") unless QuestionJourneyContract::OUTCOME_BASES.include?(outcome['basis'])
      validate_evidence(outcome['evidence'], "outcome #{id}")

      return unless outcome['basis'] == 'exhaustive_default'

      error("outcome #{id} must be standard when it is an exhaustive default") unless treatment == 'standard'
      outcome_relief_ids = relief_question_ids(outcome)
      error("outcome #{id} must declare relief_question_ids") if outcome_relief_ids.empty?
      unless outcome_relief_ids.sort == relief_rule_ids.sort
        error("outcome #{id} does not prove the journey's full relief rule set")
      end
    end

    def validate_exclusion(exclusion)
      unless exclusion.is_a?(Hash)
        error('each exclusion must be an object')
        return
      end

      id = exclusion['id']
      error('exclusion id must be a bounded, present string') unless valid_id?(id)
      error("exclusion #{id} reason must be a present string") unless present_string?(exclusion['reason'])
      validate_evidence(exclusion['evidence'], "exclusion #{id}")
    end

    def validate_evidence(evidence, location)
      unless evidence.is_a?(Hash)
        error("#{location} evidence must be present")
        return
      end

      quote = evidence['quote']
      node_id = evidence['node_id']
      error("#{location} evidence quote must be a present string") unless present_string?(quote)
      error("#{location} evidence node_id must be a present string") unless present_string?(node_id)
      return unless present_string?(quote) && present_string?(node_id)

      content_node = packet_content_by_id[node_id]
      unless content_node
        error("#{location} evidence node #{node_id} is not declared in the packet")
        return
      end

      error("#{location} evidence quote is not verbatim in #{node_id}") unless content_node['text'].to_s.include?(quote)
      %w[guide_key section_key].each do |key|
        next if evidence[key] == content_node[key]

        error("#{location} evidence #{key} does not match #{node_id}")
      end
    end

    def validate_graph
      root_id = journey['root_question_id']
      error('root_question_id must identify a question') unless questions_by_id.key?(root_id)
      return unless questions_by_id.key?(root_id)

      reachable_questions = Set.new
      reachable_outcomes = Set.new
      paths = []
      fallthroughs = []
      @graph_visits = 0
      walk(root_id, [], reachable_questions, reachable_outcomes, paths, fallthroughs)

      unreachable_questions = questions_by_id.keys - reachable_questions.to_a
      unreachable_outcomes = outcomes_by_id.keys - reachable_outcomes.to_a
      error("unreachable questions: #{unreachable_questions.join(', ')}") if unreachable_questions.any?
      error("unreachable outcomes: #{unreachable_outcomes.join(', ')}") if unreachable_outcomes.any?
      unknown_relief_rules = relief_rule_ids - questions_by_id.keys
      error("unknown relief_rule_ids: #{unknown_relief_rules.join(', ')}") if unknown_relief_rules.any?
      if fallthroughs.any? && journey['composition_required'] != true
        error('journey uses internal fallthrough but is not marked composition_required')
      end
      if fallthroughs.empty? && journey['composition_required'] == true
        error('journey is marked composition_required but has no internal fallthrough')
      end
      validate_exhaustive_defaults(paths)
    end

    def walk(question_id, path, reachable_questions, reachable_outcomes, paths, fallthroughs)
      @graph_visits += 1
      if @graph_visits > MAX_GRAPH_VISITS
        error("question graph exceeds #{MAX_GRAPH_VISITS} traversal visits")
        return
      end

      if path.pluck('question_id').include?(question_id)
        error("question graph contains a cycle at #{question_id}")
        return
      end

      question = questions_by_id[question_id]
      unless question
        error("transition targets missing question #{question_id}")
        return
      end

      reachable_questions << question_id
      question.fetch('answers', []).each do |answer|
        next unless answer.is_a?(Hash)

        next_path = path + [
          {
            'question_id' => question_id,
            'answer_id' => answer['id'],
            'relief_disposition' => answer['relief_disposition'],
          },
        ]
        transition = answer['next'] || {}
        case transition['type']
        when 'question'
          walk(transition['id'], next_path, reachable_questions, reachable_outcomes, paths, fallthroughs)
        when 'outcome'
          outcome_id = transition['id']
          if outcomes_by_id.key?(outcome_id)
            reachable_outcomes << outcome_id
            paths << { 'steps' => next_path, 'outcome_id' => outcome_id }
          else
            error("transition targets missing outcome #{outcome_id}")
          end
        when 'fallthrough'
          fallthroughs << transition
        end
      end
    end

    def validate_exhaustive_defaults(paths)
      paths.each do |path|
        outcome = outcomes_by_id.fetch(path.fetch('outcome_id'))
        next unless outcome['basis'] == 'exhaustive_default'

        outcome_relief_ids = relief_question_ids(outcome)
        missing = outcome_relief_ids - path.fetch('steps').pluck('question_id')
        error("outcome #{outcome['id']} is reachable before relief questions: #{missing.join(', ')}") if missing.any?
        non_declining = path.fetch('steps').select do |step|
          outcome_relief_ids.include?(step.fetch('question_id')) && step['relief_disposition'] != 'declined'
        end
        if non_declining.any?
          error("outcome #{outcome['id']} is reachable without every relief rule declining")
        end
      end
    end

    def normalize_hash(value, name)
      return value.deep_stringify_keys if value.is_a?(Hash)

      error("#{name} must be an object")
      {}
    end

    def validate_keys(value, allowed, location)
      unknown = value.keys - allowed
      error("#{location} has unknown fields: #{unknown.join(', ')}") if unknown.any?
    end

    def validate_required_keys(value, required, location)
      missing = required - value.keys
      error("#{location} is missing required fields: #{missing.join(', ')}") if missing.any?
    end

    def relief_rule_ids
      @relief_rule_ids ||= validate_string_id_array(journey.fetch('relief_rule_ids', []), 'relief_rule_ids')
    end

    def relief_question_ids(outcome)
      @relief_question_ids ||= {}.compare_by_identity
      @relief_question_ids[outcome] ||= validate_string_id_array(
        outcome['relief_question_ids'],
        "outcome #{outcome['id']} relief_question_ids",
      )
    end

    def validate_string_id_array(value, location)
      unless value.is_a?(Array)
        error("#{location} must be an array of present strings")
        return []
      end
      unless value.all? { |id| valid_id?(id) }
        error("#{location} must contain only bounded, present strings")
        return []
      end

      error("#{location} must contain unique ids") unless value.uniq.size == value.size
      value
    end

    def present_string?(value) = value.is_a?(String) && value.present? && value.length <= MAX_TEXT_LENGTH
    def valid_id?(value) = value.is_a?(String) && value.present? && value.length <= MAX_ID_LENGTH

    def validate_no_rate_keys(value, path = 'journey')
      case value
      when Hash
        value.each do |key, nested|
          next if path.end_with?('evidence') && key == 'quote'

          error("#{path} stores a rate-like field: #{key}") if key.match?(RATE_KEY)
          validate_no_rate_keys(nested, "#{path}.#{key}")
        end
      when Array
        value.each_with_index { |nested, index| validate_no_rate_keys(nested, "#{path}[#{index}]") }
      when String
        error("#{path} stores a numerical percentage") if value.match?(RATE_VALUE)
      end
    end

    def questions
      return @questions if defined?(@questions)

      @questions = journey['questions'].is_a?(Array) ? journey['questions'] : []
      error('questions must be an array') unless journey['questions'].is_a?(Array)
      @questions
    end

    def outcomes
      return @outcomes if defined?(@outcomes)

      @outcomes = journey['outcomes'].is_a?(Array) ? journey['outcomes'] : []
      error('outcomes must be an array') unless journey['outcomes'].is_a?(Array)
      @outcomes
    end

    def exclusions
      return @exclusions if defined?(@exclusions)

      @exclusions = journey['exclusions'].is_a?(Array) ? journey['exclusions'] : []
      error('exclusions must be an array') unless journey['exclusions'].is_a?(Array)
      @exclusions
    end

    def fallthrough_targets
      return @fallthrough_targets if defined?(@fallthrough_targets)

      @fallthrough_targets = journey['fallthrough_targets'].is_a?(Array) ? journey['fallthrough_targets'] : []
      if journey.key?('fallthrough_targets') && !journey['fallthrough_targets'].is_a?(Array)
        error('fallthrough_targets must be an array')
      end
      @fallthrough_targets
    end

    def fallthrough_targets_by_id
      @fallthrough_targets_by_id ||= fallthrough_targets.filter_map { |target|
        next unless target.is_a?(Hash)

        unless target['resolution'] == 'module_boundary' && target['required_composer'] == REQUIRED_COMPOSER
          error("fallthrough target #{target['id']} must declare the #{REQUIRED_COMPOSER} module boundary")
        end
        [target['id'], target]
      }.to_h
    end

    def questions_by_id = @questions_by_id ||= questions.grep(Hash).index_by { |question| question['id'] }
    def outcomes_by_id = @outcomes_by_id ||= outcomes.grep(Hash).index_by { |outcome| outcome['id'] }
    def packet_content_by_id = @packet_content_by_id ||= Array(packet['content']).grep(Hash).index_by { |node| node['node_id'] }
    def error(message) = errors << message
  end
end
