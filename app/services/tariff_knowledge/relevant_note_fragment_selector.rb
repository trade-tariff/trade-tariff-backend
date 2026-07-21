module TariffKnowledge
  class RelevantNoteFragmentSelector
    Selection = Data.define(:contexts, :diagnostics)

    # The classifier prompt needs source evidence, not complete compressed notes.
    # These caps keep one broad chapter/section note from dominating the prompt:
    # at most two fragments may come from one compressed note, and at most eight
    # fragments are emitted for the whole candidate set.
    MAX_FRAGMENTS_PER_NOTE = 2
    MAX_TOTAL_FRAGMENTS = 8
    MAX_LOGGED_OMITTED_EVIDENCE = 20
    MAX_LOGGED_FRAGMENT_NODE_KEYS = 20
    OMISSION_REASON_ORDER = %w[below_minimum_score per_note_limit total_evidence_limit duplicate_same_score duplicate_lower_score duplicate_source_node contained_text_duplicate].freeze

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
    RANGE_MATCH_SCORES = {
      'heading' => 12,
      'chapter' => 6,
    }.freeze
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
    QUERY_SPECIFICITY_RANKS = {
      'exact_term' => 2,
      'exact_phrase' => 1,
    }.freeze

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

    class << self
      def call(...) = new(...).call.contexts

      def call_with_diagnostics(...) = new(...).call
    end

    class OmissionCollector
      attr_reader :count

      def initialize(limit:, reason_order:)
        @limit = limit
        @reason_order = reason_order
        @count = 0
        @counts = Hash.new(0)
        @samples = Hash.new { |hash, reason| hash[reason] = [] }
      end

      def add(reason)
        @count += 1
        @counts[reason] += 1
        @samples[reason] << yield if @samples[reason].size < limit
      end

      def logged
        ordered_reasons = reason_order.select { |reason| @samples.key?(reason) } + (@samples.keys - reason_order)
        queues = ordered_reasons.index_with { |reason| @samples[reason].dup }
        entries = ordered_reasons.first(limit).filter_map { |reason| queues[reason].shift }

        ordered_reasons.cycle do |reason|
          break if entries.size >= limit || queues.values.all?(&:empty?)

          entry = queues[reason].shift
          entries << entry if entry
        end

        entries
      end

    private

      attr_reader :limit, :reason_order
    end

    def initialize(query:, search_results:, notes_by_item_id:, source_types: nil)
      @query = query.to_s
      @search_results = search_results
      @notes_by_item_id = notes_by_item_id
      @source_types = source_types&.to_set
    end

    def call
      @omissions = OmissionCollector.new(limit: MAX_LOGGED_OMITTED_EVIDENCE, reason_order: OMISSION_REASON_ORDER)
      @considered_association_count = 0
      @considered_source_node_keys = Set.new
      contexts = notes_by_item_id.each_with_object({}) do |(item_id, note), grouped|
        group = grouped[note.context_hash] ||= { key: note.context_hash, commodity_codes: [], fragments: {} }
        group[:commodity_codes] << item_id
        scored_fragments(note).each do |fragment|
          fragment = fragment.merge(best_candidate_rank: candidate_rank(item_id))
          @considered_association_count += 1
          @considered_source_node_keys << fragment[:key]
          current = group[:fragments][fragment[:key]]
          if current.nil?
            group[:fragments][fragment[:key]] = fragment
          elsif fragment[:score] > current[:score]
            record_omission(current, note.context_hash, 'duplicate_lower_score')
            group[:fragments][fragment[:key]] = fragment.merge(
              best_candidate_rank: [current[:best_candidate_rank], fragment[:best_candidate_rank]].compact.min,
            )
          else
            reason = fragment[:score] == current[:score] ? 'duplicate_same_score' : 'duplicate_lower_score'
            record_omission(fragment, note.context_hash, reason)
            group[:fragments][fragment[:key]] = current.merge(
              best_candidate_rank: [current[:best_candidate_rank], fragment[:best_candidate_rank]].compact.min,
            )
          end
        end
      end
      @considered_context_count = contexts.size

      build_selection(deduplicate_source_evidence(contexts.values))
    end

  private

    attr_reader :query, :search_results, :notes_by_item_id, :source_types, :omissions, :considered_association_count, :considered_source_node_keys, :considered_context_count

    def deduplicate_source_evidence(contexts)
      retained = {}

      contexts.each do |context|
        context[:fragments].each_value do |fragment|
          candidate = fragment.merge(
            context_hashes: [context[:key]],
            commodity_codes: context[:commodity_codes].uniq,
            owning_context_hash: context[:key],
          )
          current = retained[fragment[:key]]

          if current.nil?
            retained[fragment[:key]] = candidate
            next
          end

          strongest, other = [current, candidate].sort_by { |record| fragment_sort_key(record) }
          record_omission(other, other[:owning_context_hash], 'duplicate_source_node', retained_source_node_key: strongest[:key])
          retained[fragment[:key]] = strongest.merge(
            context_hashes: (current[:context_hashes] + candidate[:context_hashes]).uniq,
            commodity_codes: (current[:commodity_codes] + candidate[:commodity_codes]).uniq,
            graph_paths: (Array(current[:graph_paths]) + Array(candidate[:graph_paths])).uniq,
            score_reasons: (Array(strongest[:score_reasons]) + Array(other[:score_reasons])).uniq,
            best_candidate_rank: [current[:best_candidate_rank], candidate[:best_candidate_rank]].compact.min,
          )
        end
      end

      remove_contained_text_duplicates(retained.values).group_by { |fragment| fragment[:owning_context_hash] }.map do |context_hash, fragments|
        {
          key: context_hash,
          commodity_codes: fragments.flat_map { |fragment| fragment[:commodity_codes] }.uniq,
          fragments: fragments.index_by { |fragment| fragment[:key] },
        }
      end
    end

    def remove_contained_text_duplicates(fragments)
      omitted_keys = Set.new

      fragments.select { |fragment| fragment[:evidence_kind] == 'note_block' }.each do |block|
        fragments.select { |fragment| fragment[:evidence_kind] == 'note_fragment' }.each do |fragment|
          next if omitted_keys.include?(block[:key]) || omitted_keys.include?(fragment[:key])
          next unless block_contains_fragment?(block, fragment)
          next unless contained_text?(block[:text], fragment[:text])

          retained, omitted = prefer_specific_fragment?(fragment) ? [fragment, block] : [block, fragment]
          omitted_keys << omitted[:key]
          record_omission(
            omitted,
            omitted[:owning_context_hash],
            'contained_text_duplicate',
            retained_source_node_key: retained[:key],
          )
        end
      end

      fragments.reject { |fragment| omitted_keys.include?(fragment[:key]) }
    end

    def block_contains_fragment?(block, fragment)
      Array(block[:all_fragment_node_keys]).include?(fragment[:key]) || fragment[:parent_source_node_key] == block[:key]
    end

    def contained_text?(first, second)
      first = first.to_s.squish.downcase
      second = second.to_s.squish.downcase
      first.present? && second.present? && (first.include?(second) || second.include?(first))
    end

    def prefer_specific_fragment?(fragment) = fragment[:range_type] == 'heading'

    def build_selection(grouped_contexts)
      eligible_contexts = []

      grouped_contexts.each do |context|
        ranked = context[:fragments].values.sort_by { |fragment| fragment_sort_key(fragment) }
        below_minimum, eligible = ranked.partition { |fragment| fragment[:score] < MIN_SCORE }
        selected_for_note = eligible.first(MAX_FRAGMENTS_PER_NOTE)

        below_minimum.each { |fragment| record_omission(fragment, context[:key], 'below_minimum_score') }
        eligible.drop(MAX_FRAGMENTS_PER_NOTE).each { |fragment| record_omission(fragment, context[:key], 'per_note_limit') }
        eligible_contexts << context.merge(selected: selected_for_note) if selected_for_note.any?
      end

      contexts, selected_diagnostics = apply_total_limit(eligible_contexts)
      logged_omitted = omissions.logged

      Selection.new(
        contexts:,
        diagnostics: {
          status: selection_status(grouped_contexts, contexts),
          considered_note_count: considered_context_count,
          considered_evidence_count: considered_association_count,
          considered_association_count: considered_association_count,
          considered_distinct_source_count: considered_source_node_keys.size,
          selected_note_count: contexts.size,
          selected_evidence_count: contexts.sum { |context| context[:fragments].size },
          selected_distinct_source_count: selected_diagnostics
            .flat_map { |context| context[:evidence] }
            .pluck(:source_node_key)
            .compact
            .uniq
            .size,
          omitted_evidence_count: omissions.count,
          logged_omitted_evidence_count: logged_omitted.size,
          omitted_evidence_truncated: logged_omitted.size < omissions.count,
          limits: {
            minimum_score: MIN_SCORE,
            per_note: MAX_FRAGMENTS_PER_NOTE,
            total: MAX_TOTAL_FRAGMENTS,
          },
          selected_contexts: selected_diagnostics,
          omitted_evidence: logged_omitted,
        },
      )
    end

    def apply_total_limit(contexts)
      remaining = MAX_TOTAL_FRAGMENTS
      prompt_contexts = []
      diagnostic_contexts = []

      contexts
        .sort_by { |context| fragment_sort_key(context[:selected].first) + [context[:key].to_s] }
        .each do |context|
          selected = context[:selected].first(remaining)
          context[:selected].drop(remaining).each { |fragment| record_omission(fragment, context[:key], 'total_evidence_limit') }
          remaining -= selected.size
          next if selected.empty?

          commodity_codes = context[:commodity_codes].uniq
          prompt_contexts << {
            key: context[:key],
            commodity_codes:,
            fragments: selected.map { |fragment| prompt_fragment(fragment) },
          }
          diagnostic_contexts << {
            context_hash: context[:key],
            commodity_codes:,
            evidence: selected.map { |fragment| selected_evidence(fragment, context[:key]) },
          }
        end

      [prompt_contexts, diagnostic_contexts]
    end

    def selection_status(_grouped_contexts, contexts)
      return 'no_compressed_notes' if considered_context_count.zero?
      return 'selected' if contexts.any?

      'no_eligible_evidence'
    end

    def record_omission(fragment, context_hash, reason, retained_source_node_key: nil)
      omissions.add(reason) { omitted_evidence(fragment, context_hash, reason, retained_source_node_key:) }
    end

    def prompt_fragment(fragment)
      fragment.slice(:source, :source_ref, :type, :text, :score, :why_relevant)
    end

    def selected_evidence(fragment, context_hash)
      diagnostic_evidence(fragment, context_hash).merge(decision: 'selected')
    end

    def omitted_evidence(fragment, context_hash, reason, retained_source_node_key: nil)
      diagnostic_evidence(fragment, context_hash).merge(
        decision: 'omitted',
        omission_reason: reason,
        retained_source_node_key:,
      ).compact
    end

    def diagnostic_evidence(fragment, context_hash)
      fragment.except(:key, :why_relevant, :query_specificity, :all_fragment_node_keys).merge(
        context_hash:,
        context_hashes: fragment[:context_hashes] || [context_hash],
        commodity_codes: fragment[:commodity_codes],
        source_node_key: fragment[:key],
        score_reasons: fragment[:score_reasons],
      )
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
          evidence_kind: 'note_block',
          source: evidence_block['source_title'],
          source_ref: source_reference(evidence_block),
          source_type: evidence_block['source_type'],
          source_id: evidence_block['source_id'],
          source_version: evidence_block['source_version'],
          type: evidence_block['block_type'],
          all_fragment_node_keys: Array(evidence_block['fragment_node_keys']),
          fragment_node_keys: Array(evidence_block['fragment_node_keys']).first(MAX_LOGGED_FRAGMENT_NODE_KEYS),
          fragment_node_keys_truncated: Array(evidence_block['fragment_node_keys']).size > MAX_LOGGED_FRAGMENT_NODE_KEYS,
          graph_paths: [%w[contains contains applies_to]],
          text: source_text.truncate(MAX_FRAGMENT_CHARS, omission: '...'),
          score:,
          score_reasons: reasons,
          why_relevant: reasons.join('; '),
          query_specificity: block_query_specificity(evidence_block, source_text),
          range_specificity: range_specificity(evidence_block, source_text),
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
          evidence_kind: 'note_fragment',
          source: evidence_record['source_title'] || fragment_node&.title,
          source_ref: source_reference(evidence_record),
          source_type: evidence_record['source_type'],
          source_id: evidence_record['source_id'],
          source_version: evidence_record['source_version'],
          parent_source_node_key: evidence_record['parent_source_node_key'],
          parent_source_title: evidence_record['parent_source_title'],
          type: evidence_record['context_type'],
          range_node_key: evidence_record['range_node_key'],
          range_type: evidence_record['range_type'],
          range_code: evidence_record['range_code'],
          graph_paths: fragment_graph_paths(evidence_record),
          text: text.truncate(MAX_FRAGMENT_CHARS, omission: '...'),
          score:,
          score_reasons: reasons,
          why_relevant: reasons.join('; '),
          range_specificity: range_specificity(evidence_record, text),
        }
      end
    end

    def fragment_graph_paths(evidence_record)
      paths = []
      relationships = Array(evidence_record['relationships'])
      paths << %w[contains applies_to] if relationships.include?(Edge::APPLIES_TO)
      paths << %w[contains references expands_to] if evidence_record['range_node_key'].present? || evidence_record['range_type'].present?
      paths.presence || [%w[contains applies_to]]
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
      # - +12 for a direct heading match or +6 for a direct chapter match
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
      elsif evidence_block['block_type'] == 'definition' && query_contains_definition_term?(evidence_block['term'])
        score, reasons = add_score(score, reasons, EXACT_PHRASE_SCORE, "query contains definition term #{evidence_block['term'].to_s.squish.downcase}")
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

      [RANGE_MATCH_SCORES.fetch(evidence_record['range_type'], 0), "references retrieved #{evidence_record['range_type']} #{evidence_record['range_code']}"]
    end

    def range_specificity(evidence_record, text)
      return "direct_#{evidence_record['range_type']}" if range_match?(evidence_record)
      return 'mentioned_heading' if candidate_headings.any? { |code| explicit_range_mention?(text, 'heading', code) }
      return 'mentioned_chapter' if candidate_chapters.any? { |code| explicit_range_mention?(text, 'chapter', code) }

      'generic'
    end

    def range_specificity_rank(fragment)
      {
        'direct_heading' => 2,
        'mentioned_heading' => 1,
        'direct_chapter' => 0,
        'mentioned_chapter' => 0,
        'generic' => 0,
      }.fetch(fragment[:range_specificity], 0)
    end

    def fragment_sort_key(fragment)
      [
        -QUERY_SPECIFICITY_RANKS.fetch(fragment[:query_specificity], 0),
        -range_specificity_rank(fragment),
        -fragment[:score],
        fragment[:best_candidate_rank] || candidate_item_ids.size + 1,
        fragment[:source].to_s,
        fragment[:key].to_s,
      ]
    end

    def block_query_specificity(evidence_block, text)
      return 'exact_term' if exact_query_term?(evidence_block['term'])

      suppressed_single_word_match = suppress_single_word_block_match?(evidence_block['term'])
      return 'exact_phrase' if exact_query_phrase?(evidence_block['term']) && block_term_phrase_match?(evidence_block['term'])
      return 'exact_phrase' if evidence_block['block_type'] == 'definition' && query_contains_definition_term?(evidence_block['term'])
      return 'exact_phrase' if !suppressed_single_word_match && exact_query_phrase?(text)

      nil
    end

    def query_contains_definition_term?(term)
      term_phrase = term.to_s.squish.downcase
      return false if ordered_tokens(term_phrase).size < 2

      query_phrase.match?(/\b#{Regexp.escape(term_phrase)}\b/)
    end

    def explicit_range_mention?(text, type, code)
      text.to_s.match?(/\b#{Regexp.escape(type)}s?\s+#{Regexp.escape(code)}\b/i)
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

    def fragment_evidence_records(note) = evidence_records_for(note, 'evidence')

    def block_evidence_records(note) = evidence_records_for(note, 'evidence_blocks')

    def evidence_records_for(note, key)
      records = Array(note.metadata.to_h[key])
      return records unless source_types

      records.select { |record| source_types.include?(record['source_type']) }
    end

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

      text.to_s.squish.downcase.match?(/\b#{Regexp.escape(phrase)}\b/)
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

    def candidate_rank(item_id)
      index = candidate_item_ids.index(item_id)
      index ? index + 1 : candidate_item_ids.size + 1
    end

    class Bm25Scorer
      K1 = 1.2
      B = 0.75

      def initialize(documents:, query_tokens:, stop_words:)
        @stop_words = stop_words
        @query_tokens = query_tokens.to_a
        @document_tokens = documents.map { |document| tokenize(document) }.reject(&:empty?)
        @average_document_length = calculate_average_document_length
        @document_frequencies = calculate_document_frequencies
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

      attr_reader :query_tokens, :document_tokens, :average_document_length, :document_frequencies, :stop_words

      def tokenize(text) = text.to_s.downcase.scan(/[a-z0-9]{3,}/).reject { |token| stop_words.include?(token) }

      def calculate_average_document_length
        return 0.0 if document_tokens.empty?

        document_tokens.sum(&:length).fdiv(document_tokens.length)
      end

      def calculate_document_frequencies
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
