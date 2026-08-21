require 'digest'

module VatGuidance
  class CommodityJourneyComposer
    CompositionError = Class.new(StandardError)
    SUPPORTED_MODES = %i[spike production].freeze

    def initialize(commodity_code:, rule_order:, paths:, connection_proposals:, review_decisions:, applicable_measure_ids:, mode: :spike)
      @commodity_code = commodity_code
      @rule_order = rule_order
      @paths = paths.map(&:deep_stringify_keys)
      @connection_proposals = connection_proposals.map(&:deep_stringify_keys)
      @review_decisions = review_decisions.deep_stringify_keys
      @applicable_measure_ids = applicable_measure_ids.map(&:to_s).sort
      @mode = mode.to_sym
    end

    def call
      validate_review_mode!
      validate_rule_order!
      validate_quote_support!
      approved_proposals = approved_proposals_for_commodity
      exhaustion_note = build_exhaustion_note(approved_proposals)
      routes = compose_rule(0, [], [], approved_proposals, exhaustion_note)
      ensure_unique_routes!(routes)

      {
        'commodity_code' => commodity_code,
        'status' => mode == :spike ? 'spike_simulation_complete' : 'approved',
        'review_mode' => review_decisions.fetch('review_mode'),
        'production_eligible' => mode == :production,
        'rule_order' => rule_order,
        'connection_ids' => approved_proposals.pluck('id').sort,
        'resolved_answer_paths' => routes.sort_by { |route| route.fetch('id') },
        'exhaustion_note' => exhaustion_note,
      }
    end

  private

    attr_reader :commodity_code, :rule_order, :paths, :connection_proposals, :review_decisions,
                :applicable_measure_ids, :mode

    def validate_review_mode!
      raise CompositionError, "unsupported composition mode #{mode}" unless SUPPORTED_MODES.include?(mode)

      if mode == :production && review_decisions['review_mode'] != ReviewDecisionContract::AUTHORISED_MODE
        raise CompositionError, 'production composition rejects synthetic review decisions'
      end
      if mode == :production && review_decisions['production_eligible'] != true
        raise CompositionError, 'production composition requires production-eligible reviews'
      end
      return if mode == :production || review_decisions['review_mode'] == ReviewDecisionContract::SYNTHETIC_MODE

      raise CompositionError, 'spike composition requires the explicit synthetic review fixture'
    end

    def validate_rule_order!
      raise CompositionError, 'rule order must not be empty' if rule_order.empty?
      raise CompositionError, 'rule order contains duplicates' unless rule_order.uniq == rule_order

      rule_order.each do |rule_id|
        raise CompositionError, "rule #{rule_id} has no answer paths" if paths.none? { |path| path['journey_id'] == rule_id }
      end
    end

    def validate_quote_support!
      decisions = review_decisions.fetch('quote_support_decisions').index_by { |decision| decision.fetch('subject_id') }
      paths_for_ordered_rules.each do |path|
        decision = decisions[path.fetch('id')]
        validate_decision!(decision, path.fetch('id'), ReviewDecisionContract.subject_sha256(path), 'quote-support')
      end
    end

    def paths_for_ordered_rules
      paths.select { |path| rule_order.include?(path['journey_id']) }
    end

    def approved_proposals_for_commodity
      pairing_decisions = review_decisions.fetch('pairing_decisions').index_by { |decision| decision.fetch('subject_id') }
      proposals = connection_proposals.select do |proposal|
        proposal.dig('measure_snapshot', 'declarable_commodity_codes').include?(commodity_code) &&
          rule_order.include?(proposal.fetch('journey_id'))
      end
      raise CompositionError, "no connection proposal covers #{commodity_code}" if proposals.empty?

      proposals.each do |proposal|
        validate_proposal_subject!(proposal)
        validate_treatment_mapping!(proposal)
        decision = pairing_decisions[proposal.fetch('id')]
        validate_decision!(decision, proposal.fetch('id'), proposal.fetch('subject_sha256'), 'pairing')
      end
      proposals
    end

    def validate_proposal_subject!(proposal)
      expected = ReviewDecisionContract.proposal_subject_sha256(proposal)
      raise CompositionError, "tampered proposal #{proposal.fetch('id')}" unless proposal['subject_sha256'] == expected
      raise CompositionError, "wrong proposal id #{proposal.fetch('id')}" unless proposal['id'] == "connection-proposal:#{expected}"
    end

    def validate_treatment_mapping!(proposal)
      expected_code = QuestionJourneyContract::TREATMENTS.dig(proposal.fetch('treatment'), 'additional_code')
      actual_code = proposal.dig('measure_snapshot', 'additional_code')
      raise CompositionError, "proposal #{proposal.fetch('id')} uses #{actual_code} for #{proposal.fetch('treatment')}" unless expected_code == actual_code
    end

    def validate_decision!(decision, subject_id, subject_sha256, kind)
      raise CompositionError, "missing #{kind} decision for #{subject_id}" unless decision

      validate_decision_hash!(decision, subject_id, kind)
      raise CompositionError, "stale #{kind} decision for #{subject_id}" unless decision['subject_sha256'] == subject_sha256
      raise CompositionError, "unapproved #{kind} decision for #{subject_id}" unless decision['status'] == required_approval_status
      raise CompositionError, "wrong review mode for #{kind} decision #{subject_id}" unless decision['review_mode'] == review_decisions['review_mode']
      raise CompositionError, "anonymous #{kind} decision for #{subject_id}" if decision['reviewer'].blank? || decision['reviewed_at'].blank?
    end

    def validate_decision_hash!(decision, subject_id, kind)
      declared_hash = decision['decision_sha256']
      actual_hash = ReviewDecisionContract.decision_sha256(decision)
      raise CompositionError, "tampered #{kind} decision for #{subject_id}" unless declared_hash == actual_hash
    end

    def required_approval_status
      mode == :production ? ReviewDecisionContract::PRODUCTION_APPROVAL : ReviewDecisionContract::SPIKE_APPROVAL
    end

    def build_exhaustion_note(proposals)
      covered_measure_ids = proposals.map { |proposal| proposal.dig('measure_snapshot', 'measure_id') }.uniq.sort
      unless covered_measure_ids == applicable_measure_ids
        raise CompositionError, "measure exhaustion mismatch for #{commodity_code}: expected #{applicable_measure_ids.join(', ')}, covered #{covered_measure_ids.join(', ')}"
      end

      {
        'commodity_code' => commodity_code,
        'status' => 'complete_for_pinned_spike_snapshot',
        'snapshot_date' => proposals.map { |proposal| proposal.dig('measure_snapshot', 'snapshot_date') }.uniq.sole,
        'applicable_non_standard_measure_ids' => applicable_measure_ids,
        'covered_measure_ids' => covered_measure_ids,
        'covering_connections' => proposals.group_by { |proposal| proposal.dig('measure_snapshot', 'measure_id') }
                                            .transform_values { |items| items.pluck('id').sort },
        'standard_by_default_permitted_after_all_rules_decline' => true,
      }
    end

    def compose_rule(rule_index, prior_steps, component_path_ids, proposals, exhaustion_note)
      rule_id = rule_order.fetch(rule_index)
      rule_paths = paths.select { |path| path['journey_id'] == rule_id }.sort_by { |path| path.fetch('id') }

      rule_paths.flat_map do |path|
        steps = prior_steps + path.fetch('steps')
        component_ids = component_path_ids + [path.fetch('id')]
        terminal = path.fetch('terminal')

        if terminal['type'] == 'fallthrough'
          if rule_index < rule_order.length - 1
            compose_rule(rule_index + 1, steps, component_ids, proposals, exhaustion_note)
          else
            [standard_route(steps, component_ids, 'exhausted_relief_rules', exhaustion_note)]
          end
        elsif terminal['treatment'] == 'standard'
          [standard_route(steps, component_ids, 'explicit_guidance', exhaustion_note)]
        else
          matching = proposals.select { |proposal| proposal['answer_path_id'] == path['id'] }
          raise CompositionError, "no exact approved connection can resolve #{path.fetch('id')}" if matching.empty?

          [relief_route(steps, component_ids, path, matching)]
        end
      end
    end

    def relief_route(steps, component_ids, path, proposals)
      codes = proposals.map { |proposal| proposal.dig('measure_snapshot', 'additional_code') }.uniq
      treatments = proposals.pluck('treatment').uniq
      raise CompositionError, "inconsistent connections for #{path.fetch('id')}" unless codes.one? && treatments == [path.dig('terminal', 'treatment')]

      resolution = mode == :spike ? 'synthetic_spike_rule_connections' : 'authorised_rule_connections'
      route(resolution, steps, component_ids).merge(
        'treatment' => treatments.sole,
        'additional_code' => codes.sole,
        'measure_ids' => proposals.map { |proposal| proposal.dig('measure_snapshot', 'measure_id') }.uniq.sort,
        'connection_ids' => proposals.pluck('id').sort,
      )
    end

    def standard_route(steps, component_ids, resolution, exhaustion_note)
      if resolution == 'exhausted_relief_rules' && !exhaustion_note['standard_by_default_permitted_after_all_rules_decline']
        raise CompositionError, 'standard default is blocked by incomplete exhaustion'
      end

      route(resolution, steps, component_ids).merge(
        'treatment' => 'standard',
        'additional_code' => nil,
        'measure_ids' => [],
        'connection_ids' => [],
      )
    end

    def route(resolution, steps, component_ids)
      subject = {
        'commodity_code' => commodity_code,
        'component_path_ids' => component_ids,
        'steps' => steps.map { |step| step.slice('question_id', 'answer_id') },
        'resolution' => resolution,
      }
      {
        'id' => "composed-route:#{Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(subject))}",
        'component_path_ids' => component_ids,
        'steps' => steps,
        'resolution' => resolution,
      }
    end

    def ensure_unique_routes!(routes)
      ids = routes.pluck('id')
      raise CompositionError, "duplicate composed routes for #{commodity_code}" unless ids.uniq.size == ids.size
    end
  end
end
