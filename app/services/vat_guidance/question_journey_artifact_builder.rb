require 'digest'

module VatGuidance
  class QuestionJourneyArtifactBuilder
    BuildError = Class.new(StandardError)

    TARGET_NOTICE_BY_GUIDE = {
      'vat-notice-701-23' => '701/23',
      'vat-notice-701-14' => '701/14',
      'vat-notice-709-1' => '709/1',
    }.freeze
    REQUIRED_COMMODITY_CODES = %w[2005202000 2008939120 2008979890 8407100010 8409100090 8424100011].freeze
    GENERATION_METADATA_KEYS = %w[
      ticket generation_mode provider model prompt_sha256 human_review_required
    ].freeze
    CANDIDATE_KEYS = %w[
      source_packets_sha256 generation_metadata journeys packet_review_records packet_generation_attempts spike_findings
    ].freeze
    SPIKE_FINDING_KEYS = %w[id finding].freeze
    REVIEW_RECORD_KEYS = %w[
      packet_id source_packet_sha256 method status journey_ids finding model_response_sha256
    ].freeze
    REVIEW_RECORD_REQUIRED_KEYS = %w[
      packet_id source_packet_sha256 method status journey_ids finding
    ].freeze
    REVIEW_METHODS = %w[llm_generation ai_assisted_human_review].freeze
    REVIEW_STATUSES = %w[
      journey_generated journey_curated no_contract_safe_tree_identified
    ].freeze
    SHA256 = /\A[0-9a-f]{64}\z/
    COMPARISON_ROLES = %w[catering_local_only catering_reference_expanded].freeze
    RATE_KEY = QuestionJourneyContract::RATE_KEY
    RATE_VALUE = QuestionJourneyContract::RATE_VALUE

    def self.content_sha256(artifact)
      without_hash = artifact.deep_stringify_keys.except('content_sha256')
      Digest::SHA256.hexdigest(canonical_json(without_hash))
    end

    def self.canonical_json(value)
      case value
      when Hash
        "{#{value.keys.sort.map { |key| "#{key.to_json}:#{canonical_json(value.fetch(key))}" }.join(',')}}"
      when Array
        "[#{value.map { |item| canonical_json(item) }.join(',')}]"
      else
        value.to_json
      end
    end

    def initialize(packets, candidates)
      @packets = normalize_hash(packets, 'context packets')
      @candidates = normalize_hash(candidates, 'question journey candidates')
      @packets_by_id = all_packets.index_by { |packet| packet.fetch('packet_id') }
    end

    def call
      validate_candidate_envelope!
      journeys = candidates.fetch('journeys')
      validate_journey_set!(journeys)
      records = validate_packet_review_records!(journeys)
      reports = journeys.map { |journey| validation_report(journey) }
      comparison = build_comparison(journeys)
      coverage = build_packet_generation_coverage(records)
      artifact = {
        'schema_version' => QuestionJourneyContract::SCHEMA_VERSION,
        'source_packets_sha256' => packets.fetch('content_sha256'),
        'generation_metadata' => candidates.fetch('generation_metadata'),
        'human_review_status' => 'required',
        'runtime_approved' => false,
        'treatments' => QuestionJourneyContract::TREATMENTS,
        'journeys' => journeys,
        'validation_reports' => reports,
        'packet_review_records' => records,
        'packet_generation_coverage' => coverage,
        'catering_packet_comparison' => comparison,
        'spike_findings' => candidates.fetch('spike_findings', []),
        'summary' => summary(journeys, reports, records, coverage),
      }
      artifact['content_sha256'] = self.class.content_sha256(artifact)
      artifact
    end

  private

    attr_reader :packets, :candidates, :packets_by_id

    def normalize_hash(value, name)
      raise BuildError, "#{name} must be an object" unless value.is_a?(Hash)

      value.deep_stringify_keys
    end

    def validate_candidate_envelope!
      unknown_keys = candidates.keys - CANDIDATE_KEYS
      raise BuildError, "question journey candidates have unknown fields: #{unknown_keys.join(', ')}" if unknown_keys.any?

      journeys = candidates['journeys']
      raise BuildError, 'journeys must be an array' unless journeys.is_a?(Array)

      metadata = candidates['generation_metadata']
      raise BuildError, 'generation_metadata must be an object' unless metadata.is_a?(Hash)

      unknown_metadata = metadata.keys - GENERATION_METADATA_KEYS
      raise BuildError, "generation_metadata has unknown fields: #{unknown_metadata.join(', ')}" if unknown_metadata.any?

      %w[ticket generation_mode provider model prompt_sha256].each do |key|
        raise BuildError, "generation_metadata #{key} must be present" if metadata[key].blank?
      end
      unless metadata['ticket'] == 'AI-1145' && metadata['human_review_required'] == true
        raise BuildError, 'generation_metadata must identify AI-1145 and require human review'
      end
      unless metadata['prompt_sha256'] == Digest::SHA256.hexdigest(QuestionJourneyContract.generation_prompt)
        raise BuildError, 'generation prompt hash has drifted; regenerate and review the candidates'
      end
      unless candidates['source_packets_sha256'] == packets['content_sha256']
        raise BuildError, 'candidate source packet hash has drifted; regenerate and review the candidates'
      end

      validate_packet_hashes!

      validate_spike_findings!
      validate_no_stored_rates!(candidates)
    end

    def validate_spike_findings!
      findings = candidates.fetch('spike_findings', [])
      raise BuildError, 'spike_findings must be an array' unless findings.is_a?(Array) && findings.all?(Hash)

      findings.each do |finding|
        unknown = finding.keys - SPIKE_FINDING_KEYS
        raise BuildError, "spike finding has unknown fields: #{unknown.join(', ')}" if unknown.any?
        raise BuildError, 'spike finding id and finding must be present' if finding.values_at('id', 'finding').any?(&:blank?)
      end
      ids = findings.pluck('id')
      raise BuildError, 'spike finding ids must be unique' unless ids.uniq.size == ids.size
    end

    def validate_no_stored_rates!(value, path = 'candidates')
      case value
      when Hash
        value.each do |key, nested|
          next if path.end_with?('evidence') && key == 'quote'

          raise BuildError, "#{path} stores a rate-like field: #{key}" if key.match?(RATE_KEY)

          validate_no_stored_rates!(nested, "#{path}.#{key}")
        end
      when Array
        value.each_with_index { |nested, index| validate_no_stored_rates!(nested, "#{path}[#{index}]") }
      when String
        raise BuildError, "#{path} stores a numerical percentage" if value.match?(RATE_VALUE)
      end
    end

    def validate_journey_set!(journeys)
      raise BuildError, 'every journey must be an object' unless journeys.all?(Hash)

      ids = journeys.pluck('journey_id')
      raise BuildError, 'journey ids must be present and unique' unless ids.none?(&:blank?) && ids.uniq.size == ids.size

      source_packet_ids = journeys.pluck('source_packet_id')
      unless source_packet_ids.all? { |packet_id| packet_id.is_a?(String) && packet_id.present? }
        raise BuildError, 'journey source_packet_id values must be present strings'
      end

      unknown_packet_ids = source_packet_ids - packets_by_id.keys
      raise BuildError, "unknown source packet ids: #{unknown_packet_ids.join(', ')}" if unknown_packet_ids.any?

      commodity_codes = journeys.filter_map do |journey|
        packet = packets_by_id[journey['source_packet_id']]
        packet.dig('source', 'commodity_code') if packet&.dig('source', 'node_type') == 'commodity'
      end
      unless commodity_codes.sort == REQUIRED_COMMODITY_CODES.sort
        raise BuildError, "commodity journey coverage must be exactly #{REQUIRED_COMMODITY_CODES.join(', ')}"
      end

      roles = journeys.filter_map { |journey| journey['comparison_role'] }
      unknown_roles = roles - COMPARISON_ROLES
      raise BuildError, "unknown comparison roles: #{unknown_roles.join(', ')}" if unknown_roles.any?
    end

    def all_packets
      packets.fetch('packets') + packets.fetch('commodity_packets') +
        packets.fetch('comparisons').flat_map { |comparison| [comparison.fetch('local_only'), comparison.fetch('reference_expanded')] }
    end

    def validate_packet_hashes!
      declared_artifact_hash = packets.fetch('content_sha256')
      actual_artifact_hash = source_content_sha256(packets)
      raise BuildError, 'context packet artifact content hash is invalid' unless declared_artifact_hash == actual_artifact_hash

      all_packets.each do |packet|
        declared_packet_hash = packet.fetch('content_sha256')
        actual_packet_hash = source_content_sha256(packet)
        next if declared_packet_hash == actual_packet_hash

        raise BuildError, "context packet #{packet.fetch('packet_id')} content hash is invalid"
      end
    end

    def source_content_sha256(value)
      content = value.deep_stringify_keys.except('content_sha256')
      Digest::SHA256.hexdigest(JSON.generate(deep_sort(content)))
    end

    def deep_sort(value)
      case value
      when Hash then value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
      when Array then value.map { |item| deep_sort(item) }
      else value
      end
    end

    def validate_packet_review_records!(journeys)
      records = review_records
      unless records.is_a?(Array) && records.all?(Hash)
        raise BuildError, 'packet_review_records must be an array of objects'
      end
      if candidates.key?('packet_generation_attempts') && records.any? { |record| record['method'] != 'llm_generation' }
        raise BuildError, 'packet_generation_attempts may contain only llm_generation records'
      end

      packet_ids = records.pluck('packet_id')
      unless packet_ids.all? { |id| id.is_a?(String) && id.present? } && packet_ids.uniq.size == packet_ids.size
        raise BuildError, 'packet review record packet ids must be present strings and unique'
      end

      missing = packets_by_id.keys - packet_ids
      unknown = packet_ids - packets_by_id.keys
      raise BuildError, "missing packet review records: #{missing.join(', ')}" if missing.any?
      raise BuildError, "unknown packet review records: #{unknown.join(', ')}" if unknown.any?

      journeys_by_packet = journeys.group_by { |journey| journey.fetch('source_packet_id') }
      records.each do |record|
        validate_packet_review_record!(record, journeys_by_packet.fetch(record.fetch('packet_id'), []))
      end
      records
    end

    def review_records
      reviewed = candidates['packet_review_records']
      generated = candidates['packet_generation_attempts']
      if reviewed && generated
        raise BuildError, 'candidates must provide packet_review_records or packet_generation_attempts, not both'
      end

      reviewed || generated
    end

    def validate_packet_review_record!(record, expected_journeys)
      unknown = record.keys - REVIEW_RECORD_KEYS
      raise BuildError, "packet review record has unknown fields: #{unknown.join(', ')}" if unknown.any?

      missing = REVIEW_RECORD_REQUIRED_KEYS - record.keys
      raise BuildError, "packet review record has missing fields: #{missing.join(', ')}" if missing.any?

      packet_id = record.fetch('packet_id')
      packet = packets_by_id.fetch(packet_id)
      unless record['source_packet_sha256'] == packet.fetch('content_sha256')
        raise BuildError, "packet review record #{packet_id} source hash has drifted"
      end
      unless REVIEW_METHODS.include?(record['method'])
        raise BuildError, "packet review record #{packet_id} has invalid method"
      end
      unless REVIEW_STATUSES.include?(record['status'])
        raise BuildError, "packet review record #{packet_id} has invalid status"
      end

      journey_ids = record['journey_ids']
      unless journey_ids.is_a?(Array) && journey_ids.all? { |id| id.is_a?(String) && id.present? } &&
          journey_ids.uniq.size == journey_ids.size
        raise BuildError, "packet review record #{packet_id} journey_ids must be unique strings"
      end

      expected_journey_ids = expected_journeys.pluck('journey_id').sort
      unless journey_ids.sort == expected_journey_ids
        raise BuildError, "packet review record #{packet_id} does not match generated journeys"
      end

      case [record['method'], record['status']]
      when %w[llm_generation journey_generated]
        validate_llm_generation_attempt!(record, expected_journeys, packet_id)
      when %w[ai_assisted_human_review journey_curated]
        validate_manual_journey_record!(record, packet_id)
      when %w[ai_assisted_human_review no_contract_safe_tree_identified]
        validate_manual_no_tree_record!(record, packet_id)
      else
        raise BuildError, "packet review record #{packet_id} has an invalid method and status combination"
      end
    end

    def validate_llm_generation_attempt!(attempt, expected_journeys, packet_id)
      unless expected_journeys.one? && attempt['journey_ids'].one? && attempt['finding'].blank?
        raise BuildError, "packet review record #{packet_id} has invalid generated journey evidence"
      end

      response_sha256 = attempt['model_response_sha256']
      unless response_sha256.is_a?(String) && response_sha256.match?(SHA256)
        raise BuildError, "packet review record #{packet_id} must have a model response hash"
      end

      expected_sha256 = Digest::SHA256.hexdigest(self.class.canonical_json(expected_journeys.sole))
      unless ActiveSupport::SecurityUtils.secure_compare(response_sha256, expected_sha256)
        raise BuildError, "packet review record #{packet_id} model response hash has drifted"
      end
    end

    def validate_manual_journey_record!(attempt, packet_id)
      unless attempt['journey_ids'].any? && attempt['finding'].blank?
        raise BuildError, "packet review record #{packet_id} has invalid curated journey evidence"
      end

      reject_manual_model_response_hash!(attempt, packet_id)
    end

    def validate_manual_no_tree_record!(attempt, packet_id)
      unless attempt['journey_ids'].empty? && attempt['finding'].is_a?(String) && attempt['finding'].present?
        raise BuildError, "packet review record #{packet_id} has an invalid no-tree finding"
      end

      reject_manual_model_response_hash!(attempt, packet_id)
    end

    def reject_manual_model_response_hash!(attempt, packet_id)
      return unless attempt.key?('model_response_sha256')

      raise BuildError, "packet review record #{packet_id} manual review cannot have a model response hash"
    end

    def validation_report(journey)
      packet = packets_by_id.fetch(journey.fetch('source_packet_id'))
      QuestionJourneyValidator.new(journey, packet).call.as_json
    end

    def build_comparison(journeys)
      comparison = packets.fetch('comparisons').sole
      local = comparison_journey(journeys, 'catering_local_only')
      expanded = comparison_journey(journeys, 'catering_reference_expanded')
      expected_local_id = comparison.fetch('local_only').fetch('packet_id')
      expected_expanded_id = comparison.fetch('reference_expanded').fetch('packet_id')
      raise BuildError, 'catering local-only journey uses the wrong packet' unless local['source_packet_id'] == expected_local_id
      raise BuildError, 'catering reference-expanded journey uses the wrong packet' unless expanded['source_packet_id'] == expected_expanded_id

      local_prompts = local.fetch('questions').pluck('prompt')
      expanded_prompts = expanded.fetch('questions').pluck('prompt')

      {
        'source_node_id' => comparison.fetch('source_node_id'),
        'local_packet_id' => expected_local_id,
        'reference_expanded_packet_id' => expected_expanded_id,
        'local_journey_id' => local.fetch('journey_id'),
        'reference_expanded_journey_id' => expanded.fetch('journey_id'),
        'local_question_count' => local_prompts.size,
        'reference_expanded_question_count' => expanded_prompts.size,
        'questions_only_possible_with_references' => expanded_prompts - local_prompts,
      }
    end

    def comparison_journey(journeys, role)
      matches = journeys.select { |journey| journey['comparison_role'] == role }
      raise BuildError, "expected exactly one #{role} journey" unless matches.one?

      matches.first
    end

    def build_packet_generation_coverage(records)
      records_by_packet_id = records.index_by { |record| record.fetch('packet_id') }
      packets.fetch('packets').map do |packet|
        source = packet.fetch('source')
        record = records_by_packet_id.fetch(packet.fetch('packet_id'))
        {
          'packet_id' => packet.fetch('packet_id'),
          'guide_key' => source.fetch('guide_key'),
          'notice_number' => TARGET_NOTICE_BY_GUIDE.fetch(source.fetch('guide_key')),
          'section_key' => source.fetch('section_key'),
          'source_packet_sha256' => record.fetch('source_packet_sha256'),
          'method' => record.fetch('method'),
          'status' => record.fetch('status'),
          'journey_ids' => record.fetch('journey_ids'),
          'finding' => record['finding'],
        }
      end
    end

    def summary(journeys, reports, records, coverage)
      notices = journeys.filter_map do |journey|
        source = packets_by_id.fetch(journey.fetch('source_packet_id')).fetch('source')
        TARGET_NOTICE_BY_GUIDE[source['guide_key']]
      end
      commodity_sources = journeys.filter_map do |journey|
        source = packets_by_id.fetch(journey.fetch('source_packet_id')).fetch('source')
        source if source['node_type'] == 'commodity'
      end
      {
        'journeys' => journeys.size,
        'valid_journeys' => reports.count { |report| report.fetch('valid') },
        'invalid_journeys' => reports.count { |report| !report.fetch('valid') },
        'notices_covered' => notices.uniq.sort,
        'packet_review_records' => records.size,
        'packet_review_records_accounted_for' => records.count,
        'target_notice_packets' => coverage.size,
        'target_notice_packets_accounted_for' => coverage.count,
        'target_notice_packets_with_journeys' => coverage.count do |item|
          %w[journey_generated journey_curated].include?(item['status'])
        end,
        'commodity_journeys' => commodity_sources.size,
        'commodity_codes' => commodity_sources.pluck('commodity_code').sort,
        'commodity_chapters' => commodity_sources.pluck('chapter').uniq.sort,
        'exclusions' => journeys.sum { |journey| Array(journey['exclusions']).size },
      }
    end
  end
end
