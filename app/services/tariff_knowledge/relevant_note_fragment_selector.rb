module TariffKnowledge
  class RelevantNoteFragmentSelector
    # The classifier prompt needs source evidence, not complete compressed notes.
    # These caps keep one broad chapter/section note from dominating the prompt:
    # at most two fragments may come from one compressed note, and at most eight
    # fragments are emitted for the whole candidate set.
    MAX_FRAGMENTS_PER_NOTE = 2
    MAX_TOTAL_FRAGMENTS = 8

    # A fragment must show more than generic relevance before it is emitted.
    # For example, an exclusion fragment starts at 3 points, so it still needs
    # a candidate-range match or query-term overlap to pass this threshold.
    MIN_SCORE = 6
    MAX_FRAGMENT_CHARS = 700
    CONTEXT_TYPE_SCORES = {
      'exclusion' => 3,
      'inclusion' => 2,
      'reference' => 1,
    }.freeze
    RANGE_MATCH_SCORE = 8
    MENTIONED_RANGE_SCORE = 4
    MAX_MENTIONED_RANGE_SCORE = 12
    QUERY_TERM_SCORE = 2
    MAX_QUERY_TERM_SCORE = 10
    SAME_CHAPTER_SCORE = 1
    EXACT_PHRASE_SCORE = 14
    EXACT_TERM_SCORE = 4
    DEFINITION_BLOCK_SCORE = 4
    BM25_SCORE_MULTIPLIER = 2
    MAX_BM25_SCORE = 8
    MAX_REASON_CODES = 4
    MAX_REASON_TERMS = 5

    # Rules are evaluated in this order so range evidence wins first, then text
    # mentions of retrieved chapters/headings, then query-language overlap, with
    # same-chapter evidence acting only as a small tie-breaker.
    SCORING_RULES = [
      ->(evidence_record, _text) { range_match_rule(evidence_record) },
      ->(_evidence, text) { mentioned_range_rule(text) },
      ->(_evidence, text) { query_term_rule(text) },
      ->(_evidence, text) { bm25_rule(text) },
      ->(evidence_record, _text) { same_chapter_rule(evidence_record) },
    ].freeze
    STOP_WORDS = %w[above an and are article articles as at be by chapter chapters code codes for from goods has have heading headings in into is it its kind made nomenclature of on or other purposes than that the this to use used with without].to_set.freeze

    def self.call(...) = new(...).call

    def initialize(query:, search_results:, notes_by_item_id:)
      @query = query.to_s
      @search_results = search_results
      @notes_by_item_id = notes_by_item_id
    end

    def call
      contexts = notes_by_item_id.each_with_object({}) do |(item_id, note), grouped|
        group = grouped[note.context_hash] ||= { key: note.context_hash, commodity_codes: [], fragments: {} }
        group[:commodity_codes] << item_id
        scored_fragments(note).each do |fragment|
          current = group[:fragments][fragment[:key]]
          group[:fragments][fragment[:key]] = fragment if current.nil? || fragment[:score] > current[:score]
        end
      end

      cap_total_fragments(contexts.values.filter_map { |context| selected_context(context) })
    end

  private

    attr_reader :query, :search_results, :notes_by_item_id

    def selected_context(context)
      fragments = context[:fragments].values.select { |fragment| fragment[:score] >= MIN_SCORE }
        .sort_by { |fragment| [-fragment[:score], fragment[:source].to_s, fragment[:key].to_s] }.first(MAX_FRAGMENTS_PER_NOTE)
        .map { |fragment| fragment.except(:key) }
      { key: context[:key], commodity_codes: context[:commodity_codes].uniq, fragments: } if fragments.any?
    end

    def cap_total_fragments(contexts)
      remaining = MAX_TOTAL_FRAGMENTS
      contexts
        .sort_by { |context| [-context[:fragments].first[:score], context[:key].to_s] }
        .filter_map do |context|
          fragments = context[:fragments].first(remaining)
          remaining -= fragments.size
          context.merge(fragments:) if fragments.any?
        end
    end

    def scored_fragments(note)
      scored_block_records(note) + scored_fragment_records(note)
    end

    def scored_block_records(note)
      block_evidence_records(note).filter_map do |evidence_block|
        source_text = evidence_block['source_context'].to_s.squish
        next if source_text.blank?

        score, reasons = score_block(evidence_block, source_text)
        {
          key: evidence_block['source_node_key'],
          source: evidence_block['source_title'],
          source_ref: source_reference(evidence_block),
          type: evidence_block['block_type'],
          text: source_text.truncate(MAX_FRAGMENT_CHARS, omission: '...'),
          score:,
          why_relevant: reasons.join('; '),
        }
      end
    end

    def scored_fragment_records(note)
      # Each record is compressed-note metadata pointing to a source fragment and
      # explaining the relationship that made that fragment evidence for a code.
      fragment_evidence_records(note).filter_map do |evidence_record|
        fragment_node = fragment_node_for(evidence_record)
        text = (evidence_record['source_context'].presence || fragment_node&.content).to_s.squish
        next if text.blank?

        score, reasons = score_fragment(evidence_record, text)
        {
          key: evidence_record['source_node_key'],
          source: evidence_record['source_title'] || fragment_node&.title,
          source_ref: source_reference(evidence_record),
          type: evidence_record['context_type'],
          text: text.truncate(MAX_FRAGMENT_CHARS, omission: '...'),
          score:,
          why_relevant: reasons.join('; '),
        }
      end
    end

    def fragment_node_for(evidence_record)
      return if evidence_record['source_context'].present? && evidence_record['source_title'].present?

      fragment_nodes_by_key[evidence_record['source_node_key']]
    end

    def score_fragment(evidence_record, text)
      # Scoring is intentionally simple and explainable because the selected
      # fragments are shown to an LLM as legal/source evidence.
      #
      # Base weight reflects rule usefulness:
      # - exclusions are often decisive boundary rules, so +3
      # - inclusions are useful positive scope evidence, so +2
      # - references are weaker context, so +1
      #
      # Relevance then comes from links to the current classification problem:
      # - +8 when the evidence range directly matches a candidate chapter/heading
      # - up to +12 when the text mentions candidate chapter/heading ranges
      # - up to +10 when legal text overlaps with meaningful query terms
      # - +1 as a small same-chapter tie-breaker for chapter-note evidence only
      #
      # The score is not a legal ranking. It is a prompt-selection heuristic for
      # choosing small, auditable fragments that are likely to help classify the
      # candidate set without sending whole compressed notes.
      score = CONTEXT_TYPE_SCORES.fetch(evidence_record['context_type'], 0)
      reasons = ["#{evidence_record['context_type']} evidence"].select { score.positive? }

      SCORING_RULES.each do |rule|
        rule_result = instance_exec(evidence_record, text, &rule)
        score, reasons = add_score(score, reasons, *rule_result) if rule_result
      end

      [score, reasons]
    end

    def score_block(evidence_block, text)
      score = 0
      reasons = []

      if exact_query_term?(evidence_block['term'])
        score, reasons = add_score(score, reasons, EXACT_TERM_SCORE, "exact term match #{query_phrase}")
      end

      suppressed_single_word_match = suppress_single_word_block_match?(evidence_block['term'])

      if exact_query_phrase?(evidence_block['term']) && block_term_phrase_match?(evidence_block['term'])
        score, reasons = add_score(score, reasons, EXACT_PHRASE_SCORE, "exact phrase match #{query_phrase} in term")
      elsif !suppressed_single_word_match && exact_query_phrase?(text)
        score, reasons = add_score(score, reasons, EXACT_PHRASE_SCORE, "exact phrase match #{query_phrase}")
      end

      if evidence_block['block_type'] == 'definition'
        score, reasons = add_score(score, reasons, DEFINITION_BLOCK_SCORE, 'definition block')
      end

      [
        range_match_rule(evidence_block),
        mentioned_range_rule(text),
        query_term_rule(block_query_text(text, suppressed_single_word_match)),
        bm25_rule(block_query_text(text, suppressed_single_word_match)),
        same_chapter_rule(evidence_block),
      ].compact.each { |points, reason| score, reasons = add_score(score, reasons, points, reason) }

      [score, reasons]
    end

    def add_score(score, reasons, points, reason) = [score + points, reasons + [reason]]

    def range_match_rule(evidence_record)
      return unless range_match?(evidence_record)

      [RANGE_MATCH_SCORE, "references retrieved #{evidence_record['range_type']} #{evidence_record['range_code']}"]
    end

    def mentioned_range_rule(text)
      # Match explicit legal range phrases only. A bare "9506" in prose is too
      # ambiguous; "heading 9506" or "chapter 95" is useful classification context.
      mentioned_codes = candidate_ranges.select { |code| text.match?(/\b(?:chapter|chapters|heading|headings)\s+#{Regexp.escape(code)}\b/i) }
      return if mentioned_codes.empty?

      [
        [mentioned_codes.size * MENTIONED_RANGE_SCORE, MAX_MENTIONED_RANGE_SCORE].min,
        "mentions retrieved ranges #{mentioned_codes.first(MAX_REASON_CODES).join(', ')}",
      ]
    end

    def query_term_rule(text)
      overlap = relevance_tokens.intersection(tokenize(text)).to_a
      return if overlap.empty?

      [
        [overlap.size * QUERY_TERM_SCORE, MAX_QUERY_TERM_SCORE].min,
        "matches query terms #{overlap.first(MAX_REASON_TERMS).join(', ')}",
      ]
    end

    def bm25_rule(text)
      return if bm25_query_tokens.empty?

      matched_terms = bm25_query_tokens.intersection(tokenize(text)).to_a
      return if matched_terms.size < 2

      bm25_score = bm25_scorer.score(text)
      return unless bm25_score.positive?

      [
        [[(bm25_score * BM25_SCORE_MULTIPLIER).round, 1].max, MAX_BM25_SCORE].min,
        "BM25 lexical match #{matched_terms.first(MAX_REASON_TERMS).join(', ')}",
      ]
    end

    def same_chapter_rule(evidence_record)
      return unless evidence_record['source_node_key'].to_s.include?(':customs_tariff_chapter_note:')
      return unless candidate_chapters.include?(evidence_record['source_id'].to_s.rjust(2, '0'))

      [SAME_CHAPTER_SCORE, 'same chapter as retrieved candidate']
    end

    def source_reference(evidence_record)
      case evidence_record['source_type'].to_s
      when 'customs_tariff_chapter_note'
        "chapter #{evidence_record['source_id'].to_s.rjust(2, '0')} note"
      when 'customs_tariff_section_note'
        "section #{evidence_record['source_id']} note"
      when 'customs_tariff_general_rule'
        "GIR #{evidence_record['source_id']}"
      end
    end

    def range_match?(evidence_record)
      code = evidence_record['range_code'].to_s
      case evidence_record['range_type']
      when 'chapter'
        # Range metadata is created only when the source fragment positively
        # references a chapter. If that chapter is in the retrieved candidates,
        # the fragment earns the direct range-match boost even when the rendered
        # context text does not repeat the code or uses non-padded wording.
        candidate_chapters.include?(code.rjust(2, '0'))
      when 'heading'
        candidate_headings.include?(code)
      else
        false
      end
    end

    def fragment_nodes_by_key
      @fragment_nodes_by_key ||= begin
        keys = notes_by_item_id.values.flat_map { |note| fallback_fragment_keys(note) }.compact.uniq
        keys.empty? ? {} : Node.note_fragments.where(key: keys).all.index_by(&:key)
      end
    end

    def fragment_evidence_records(note) = Array(note.metadata.to_h['evidence'])

    def block_evidence_records(note) = Array(note.metadata.to_h['evidence_blocks'])

    def fallback_fragment_keys(note)
      fragment_evidence_records(note).filter_map do |evidence_record|
        evidence_record['source_node_key'] if evidence_record['source_context'].blank? || evidence_record['source_title'].blank?
      end
    end

    def relevance_tokens = @relevance_tokens ||= tokenize(query)

    def bm25_query_tokens = @bm25_query_tokens ||= relevance_tokens

    def query_phrase = @query_phrase ||= query.to_s.squish.downcase

    def exact_query_term?(term)
      query_phrase.present? && term.to_s.squish.downcase == query_phrase
    end

    def exact_query_phrase?(text)
      phrase = query_phrase
      return false if phrase.blank?

      text.to_s.squish.downcase.include?(phrase)
    end

    def block_term_phrase_match?(term)
      return true unless single_relevance_token?

      exact_query_term?(term) || head_term_match?(term)
    end

    def block_query_text(text, suppressed_modifier_match)
      return text unless suppressed_modifier_match

      ''
    end

    def suppress_single_word_block_match?(term)
      single_relevance_token? && !block_term_phrase_match?(term)
    end

    def single_relevance_token?
      relevance_tokens.one?
    end

    def single_relevance_token
      relevance_tokens.first
    end

    def head_term_match?(term)
      ordered_tokens(term).last == single_relevance_token
    end

    # Keep token matching intentionally coarse: legal fragments and trader
    # queries use different grammar, so this only rewards shared meaningful
    # words/numbers after dropping common tariff/search glue words.
    def tokenize(text) = text.to_s.downcase.scan(/[a-z0-9]{3,}/).reject { |token| STOP_WORDS.include?(token) }.to_set

    def ordered_tokens(text) = text.to_s.downcase.scan(/[a-z0-9]{3,}/).reject { |token| STOP_WORDS.include?(token) }

    def bm25_scorer
      @bm25_scorer ||= Bm25Scorer.new(
        documents: evidence_corpus,
        query_tokens: bm25_query_tokens,
        stop_words: STOP_WORDS,
      )
    end

    def evidence_corpus
      @evidence_corpus ||= notes_by_item_id.values.flat_map do |note|
        block_evidence_records(note).map { |record| record['source_context'].to_s } +
          fragment_evidence_records(note).map { |record| record['source_context'].to_s }
      end
    end

    def candidate_chapters = @candidate_chapters ||= candidate_item_ids.map { |item_id| item_id.first(2) }.uniq

    def candidate_headings = @candidate_headings ||= candidate_item_ids.map { |item_id| item_id.first(4) }.uniq

    def candidate_ranges = @candidate_ranges ||= (candidate_chapters + candidate_headings).uniq

    def candidate_item_ids = @candidate_item_ids ||= search_results.map(&:goods_nomenclature_item_id).compact_blank.uniq

    class Bm25Scorer
      K1 = 1.2
      B = 0.75

      def initialize(documents:, query_tokens:, stop_words:)
        @stop_words = stop_words
        @query_tokens = query_tokens.to_a
        @document_tokens = documents.map { |document| tokenize(document) }.reject(&:empty?)
        @average_document_length = average_document_length
        @document_frequencies = document_frequencies
      end

      def score(document)
        tokens = tokenize(document)
        return 0.0 if tokens.empty? || query_tokens.empty? || document_tokens.empty?

        term_frequencies = tokens.tally
        query_tokens.sum do |term|
          next 0.0 unless term_frequencies[term]

          idf(term) * term_weight(term_frequencies[term], tokens.length)
        end
      end

    private

      attr_reader :query_tokens, :document_tokens, :stop_words

      def tokenize(text) = text.to_s.downcase.scan(/[a-z0-9]{3,}/).reject { |token| stop_words.include?(token) }

      def average_document_length
        return 0.0 if document_tokens.empty?

        document_tokens.sum(&:length).fdiv(document_tokens.length)
      end

      def document_frequencies
        document_tokens.each_with_object(Hash.new(0)) do |tokens, frequencies|
          tokens.uniq.each { |token| frequencies[token] += 1 }
        end
      end

      def idf(term)
        document_count = document_tokens.length
        frequency = document_frequencies.fetch(term, 0)

        Math.log(1 + ((document_count - frequency + 0.5) / (frequency + 0.5)))
      end

      def term_weight(term_frequency, document_length)
        denominator = term_frequency + K1 * (1 - B + (B * document_length / average_document_length))
        (term_frequency * (K1 + 1)) / denominator
      end
    end
  end
end
