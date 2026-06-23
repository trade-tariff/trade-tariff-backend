module TariffKnowledge
  class SemanticRuleFactValidator
    RELATIONSHIP_TYPES = %w[excludes includes constrains references classifies].freeze
    ACCEPTED_CONFIDENCES = %w[high medium].freeze
    REFERENCE_PATTERNS = {
      'section' => /\A\d{1,2}\z/,
      'chapter' => /\A\d{2}\z/,
      'heading' => /\A\d{4}\z/,
      'commodity' => /\A\d{10}\z/,
      'range' => /\A\d{2,10}(?:-\d{2,10})?\z/,
      'rule' => /\A(?:GIR\s*)?\d+\z/i,
    }.freeze

    def self.call(facts:, source_text:, valid_references:, target_references: nil)
      new(facts, source_text, valid_references, target_references).call
    end

    def initialize(facts, source_text, valid_references, target_references)
      @facts = Array(facts)
      @source_text = source_text.to_s
      @valid_references = Array(valid_references).filter_map { |reference| normalized_hash(reference)&.slice('type', 'code') }.to_set
      @target_references = Array(target_references || valid_references).filter_map { |reference| normalized_hash(reference)&.slice('type', 'code') }.to_set
    end

    def call
      facts.filter_map { |fact| normalize_fact(fact) }
    end

  private

    attr_reader :facts, :source_text, :valid_references, :target_references

    def normalize_fact(fact)
      return unless fact.is_a?(Hash)

      normalize(fact)
    end

    def normalize(fact)
      source_span = fact['source_span'].to_s.squish
      relationship_type = fact['relationship_type'].to_s
      subject = normalized_reference(fact['subject'])
      target = normalized_reference(fact['target'])
      confidence = fact['confidence'].to_s
      source_reference = normalized_required_string(fact['source_reference'])
      conditions = normalized_string_array(fact['conditions'])
      exceptions = normalized_string_array(fact['exceptions'])

      return if source_span.blank?
      return unless source_text.include?(source_span)
      return unless RELATIONSHIP_TYPES.include?(relationship_type)
      return unless source_reference
      return unless subject && target && valid_reference?(subject) && valid_target_reference?(target)
      return unless conditions && exceptions
      return unless ACCEPTED_CONFIDENCES.include?(confidence)

      {
        'source_reference' => source_reference,
        'source_span' => source_span,
        'relationship_type' => relationship_type,
        'subject' => subject,
        'target' => target,
        'conditions' => conditions,
        'exceptions' => exceptions,
        'confidence' => confidence,
      }
    end

    def normalized_reference(reference)
      reference = normalized_hash(reference)
      return unless reference

      type = reference['type'].to_s
      code = reference['code'].to_s
      return unless REFERENCE_PATTERNS.fetch(type, nil)&.match?(code)

      { 'type' => type, 'code' => code }
    end

    def valid_reference?(reference)
      valid_references.include?(reference)
    end

    def valid_target_reference?(reference)
      valid_reference?(reference) && target_references.include?(reference)
    end

    def normalized_string_array(values)
      return [] if values.nil?
      return unless values.is_a?(Array)
      return unless values.all? { |value| value.is_a?(String) }

      values.filter_map do |value|
        value.squish.presence
      end
    end

    def normalized_required_string(value)
      value.squish.presence if value.is_a?(String)
    end

    def normalized_hash(value)
      value if value.is_a?(Hash)
    end
  end
end
