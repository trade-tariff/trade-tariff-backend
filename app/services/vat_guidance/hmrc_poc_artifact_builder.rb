require 'digest'
require 'json'

module VatGuidance
  class HmrcPocArtifactBuilder
    BuildError = Class.new(StandardError)
    SCHEMA_VERSION = 1
    REQUIRED_COMMODITY_CODES = QuestionJourneyArtifactBuilder::REQUIRED_COMMODITY_CODES
    SIGNPOST_JOURNEY_ID = 'notice-701-23-industrial-protective-equipment'.freeze
    RULE_DEFINITIONS = {
      'rule-family:industrial-protective-equipment' => {
        'source_journey_id' => 'notice-701-23-industrial-protective-equipment',
        'origin' => 'notice_rule',
        'measure_ids' => %w[-1012552782],
      },
      'rule-family:child-car-seats' => {
        'source_journey_id' => 'notice-701-23-child-car-seats',
        'origin' => 'notice_rule',
        'measure_ids' => %w[-1012549006],
      },
      'rule-family:food-exceptions' => {
        'source_journey_id' => 'notice-701-14-food-exceptions',
        'origin' => 'notice_rule',
        'measure_ids' => %w[-1012550499 -1012550520],
        'restricted_commodity_codes' => %w[2005202000 2008939120 2008979890],
      },
      'rule-family:potato-crisps-exception' => {
        'source_journey_id' => 'commodity-2005202000-potato-crisps',
        'origin' => 'curated_guidance_rule_extraction',
        'measure_ids' => [],
        'restricted_commodity_codes' => %w[2005202000],
      },
      'rule-family:dried-cranberries-exception' => {
        'source_journey_id' => 'commodity-2008939120-sweetened-dried-cranberries',
        'origin' => 'curated_guidance_rule_extraction',
        'measure_ids' => %w[-1012550520],
        'restricted_commodity_codes' => %w[2008939120],
      },
      'rule-family:prepared-fruit-exception' => {
        'source_journey_id' => 'commodity-2008979890-prepared-fruit-mixtures',
        'origin' => 'curated_guidance_rule_extraction',
        'measure_ids' => %w[-1012550520],
        'restricted_commodity_codes' => %w[2008979890],
      },
      'rule-family:civil-aircraft-engines' => {
        'source_journey_id' => 'commodity-8407100010-civil-aircraft-engines',
        'origin' => 'curated_guidance_rule_extraction',
        'measure_ids' => %w[-1012986553],
      },
      'rule-family:aircraft-engine-parts' => {
        'source_journey_id' => 'commodity-8409100090-aircraft-engine-parts',
        'origin' => 'curated_guidance_rule_extraction',
        'measure_ids' => %w[-1012984751],
      },
      'rule-family:aircraft-fire-extinguisher-cylinders' => {
        'source_journey_id' => 'commodity-8424100011-aircraft-fire-extinguisher-cylinders',
        'origin' => 'curated_guidance_rule_extraction',
        'measure_ids' => %w[-1012980985],
      },
    }.freeze
    COMMODITY_SPECIFIC_RULES = {
      '2005202000' => 'rule-family:potato-crisps-exception',
      '2008939120' => 'rule-family:dried-cranberries-exception',
      '2008979890' => 'rule-family:prepared-fruit-exception',
    }.freeze
    WRONG_RELIEF_CHALLENGES = {
      'rule-family:industrial-protective-equipment' => 'A cycle or leisure helmet is classified in the inherited headgear cohort and described as protective, but an honest trader answers that it is not designed for industrial use.',
      'rule-family:child-car-seats' => 'A general vehicle seat is classified under the same seat commodity but is not a child restraint, so an honest trader must decline the qualifying-child-seat question.',
      'rule-family:food-exceptions' => 'A covered prepared food is sold as confectionery or in the course of catering; classification and VATZ availability do not make the trader\'s honest exception answer “No”.',
      'rule-family:dried-cranberries-exception' => 'Sweetened cranberries are marketed only as confectionery rather than for home baking, so the same commodity must not inherit the zero outcome.',
      'rule-family:prepared-fruit-exception' => 'A preparation is marketed for brewing, confectionery, or is not food fit for consumption, so classification alone must not reach the zero-food path.',
      'rule-family:civil-aircraft-engines' => 'An engine has the covered classification but is destined for a private recreational aircraft, so an honest destination/use answer must decline relief.',
      'rule-family:aircraft-engine-parts' => 'A propulsion part is classified in the inherited cohort but is destined for a domestic private aircraft, so the international/state-aircraft conditions decline.',
      'rule-family:aircraft-fire-extinguisher-cylinders' => 'A cylinder has the covered classification but is not destined for installation in a qualifying aircraft, so the destination condition declines.',
    }.freeze

    def initialize(context_graph, context_packets, question_journeys, tariff_snapshot = nil)
      @context_graph = context_graph.deep_stringify_keys
      @context_packets = context_packets.deep_stringify_keys
      @question_journeys = question_journeys.deep_stringify_keys
      @tariff_snapshot = (tariff_snapshot || default_tariff_snapshot).deep_stringify_keys
    end

    def call
      validate_source!
      enumeration = AnswerPathEnumerator.new(question_journeys).call
      paths = enumeration.fetch('answer_paths')
      exclusions = enumeration.fetch('exclusions')
      validate_accounting!(paths, exclusions)
      rule_paths = build_rule_paths(paths)
      connection_proposals = build_connection_proposals(rule_paths)
      spike_reviews = SpikeReviewFixture.new(
        paths: paths + rule_paths,
        exclusions: exclusions,
        connection_proposals: connection_proposals,
      ).call
      composed_journeys = build_composed_journeys(rule_paths, connection_proposals, spike_reviews)

      artifact = {
        'schema_version' => SCHEMA_VERSION,
        'ticket' => 'AI-1146',
        'source_question_journeys_sha256' => question_journeys.fetch('content_sha256'),
        'upstream_evidence' => upstream_evidence,
        'spike_status' => {
          'workflow_demo_ready' => true,
          'mapping_review_ready' => true,
          'end_to_end_simulation_ready' => true,
          'hmrc_demo_ready' => false,
          'production_ready' => false,
          'runtime_approved' => false,
          'human_review_status' => 'required',
          'reason' => 'This PoC simulates review, exact measure exhaustion and end-to-end composition for a pinned inherited cohort; HMRC and tax-content approval remain pending.',
        },
        'service_position' => 'The service guides using the trader\'s own answers and presents candidate VAT treatments for review. It does not determine VAT liability on the trader\'s behalf.',
        'section_packet_reviews' => question_journeys.fetch('packet_review_records'),
        'answer_paths' => paths,
        'rule_paths' => rule_paths,
        'exclusions' => exclusions,
        'measure_connection_proposals' => connection_proposals,
        'synthetic_spike_reviews' => spike_reviews,
        'composed_commodity_journeys' => composed_journeys,
        'commodity_exhaustion_notes' => composed_journeys.map { |journey| journey.fetch('exhaustion_note') },
        'signpost_assessments' => [
          {
            'commodity_code' => '6506101000',
            'label' => 'Safety headgear of plastics',
            'status' => 'end_to_end_spike_simulated_pending_real_review',
            'finding' => 'The pinned snapshot confirms VATZ measure -1012552782 reaches both declarable descendants. The same full-cohort and wrong-relief checks are now exercised for the scoped Chapter 20 and Chapter 84 measures.',
          },
        ],
        'upstream_findings' => question_journeys.fetch('spike_findings'),
        'summary' => build_summary(paths, exclusions, connection_proposals, spike_reviews, composed_journeys),
      }
      artifact['content_sha256'] = QuestionJourneyArtifactBuilder.content_sha256(artifact)
      artifact
    end

  private

    attr_reader :context_graph, :context_packets, :question_journeys, :tariff_snapshot

    def validate_source!
      validate_content_hash!(context_graph, 'context graph')
      validate_content_hash!(context_packets, 'context packet artifact')
      validate_question_style_content_hash!(tariff_snapshot, 'spike tariff snapshot')
      TariffSnapshotContract.new(tariff_snapshot).validate!

      unless context_packets['source_graph_sha256'] == context_graph['content_sha256']
        raise BuildError, 'context packet artifact is not bound to the supplied context graph'
      end
      unless question_journeys['source_packets_sha256'] == context_packets['content_sha256']
        raise BuildError, 'question journey artifact is not bound to the supplied context packets'
      end

      expected_hash = QuestionJourneyArtifactBuilder.content_sha256(question_journeys)
      raise BuildError, 'question journey artifact content hash is invalid' unless question_journeys['content_sha256'] == expected_hash
      raise BuildError, 'question journey artifact must remain non-runtime' unless question_journeys['runtime_approved'] == false
      raise BuildError, 'question journey artifact must still require human review' unless question_journeys['human_review_status'] == 'required'

      reports = question_journeys.fetch('validation_reports')
      raise BuildError, 'all source question journeys must validate' unless reports.all? { |report| report['valid'] == true }
    rescue TariffSnapshotContract::ValidationError => e
      raise BuildError, e.message
    end

    def default_tariff_snapshot
      path = File.expand_path('../../../data/vat_guidance/spike_tariff_snapshot.json', __dir__)
      JSON.parse(File.read(path))
    end

    def validate_question_style_content_hash!(artifact, label)
      actual_hash = QuestionJourneyArtifactBuilder.content_sha256(artifact)
      raise BuildError, "#{label} content hash is invalid" unless artifact['content_sha256'] == actual_hash
    end

    def validate_content_hash!(artifact, label)
      declared_hash = artifact.fetch('content_sha256')
      content = artifact.except('content_sha256')
      actual_hash = Digest::SHA256.hexdigest(JSON.generate(deep_sort(content)))
      raise BuildError, "#{label} content hash is invalid" unless declared_hash == actual_hash
    end

    def deep_sort(value)
      case value
      when Hash then value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
      when Array then value.map { |item| deep_sort(item) }
      else value
      end
    end

    def upstream_evidence
      {
        'context_graph' => {
          'content_sha256' => context_graph.fetch('content_sha256'),
          'summary' => context_graph.fetch('summary'),
        },
        'context_packets' => {
          'content_sha256' => context_packets.fetch('content_sha256'),
          'source_graph_sha256' => context_packets.fetch('source_graph_sha256'),
          'summary' => context_packets.fetch('summary'),
          'traversal_policy' => context_packets.fetch('traversal_policy'),
        },
        'question_journeys' => {
          'content_sha256' => question_journeys.fetch('content_sha256'),
          'source_packets_sha256' => question_journeys.fetch('source_packets_sha256'),
          'summary' => question_journeys.fetch('summary'),
        },
        'tariff_snapshot' => {
          'content_sha256' => tariff_snapshot.fetch('content_sha256'),
          'snapshot_date' => tariff_snapshot.fetch('snapshot_date'),
          'measures' => tariff_snapshot.fetch('measures').size,
          'independently_verified_commodities' => tariff_snapshot.fetch('commodity_measure_inventory').size,
          'declarable_measure_pairings' => tariff_snapshot.fetch('measures').sum do |measure|
            measure.fetch('declarable_commodity_codes').size
          end,
        },
      }
    end

    def validate_accounting!(paths, exclusions)
      journey_ids = question_journeys.fetch('journeys').pluck('journey_id')
      missing_journeys = journey_ids - paths.pluck('journey_id').uniq
      raise BuildError, "journeys without paths: #{missing_journeys.join(', ')}" if missing_journeys.any?

      paths.each do |path|
        review = path.fetch('review')
        terminal = path.fetch('terminal')
        raise BuildError, "path #{path.fetch('id')} is not accounted for" unless %w[disposition connection_candidate].include?(review['kind'])
        if terminal['type'] == 'outcome' && terminal['treatment'] == 'standard' && review['kind'] != 'disposition'
          raise BuildError, "standard path #{path.fetch('id')} must be a disposition"
        end

        next unless review['kind'] == 'connection_candidate'

        raise BuildError, "commodity path #{path.fetch('id')} cannot originate a connection" if path.dig('scope', 'type') == 'commodity'

        expected_code = QuestionJourneyContract::TREATMENTS.fetch(terminal.fetch('treatment')).fetch('additional_code')
        raise BuildError, "path #{path.fetch('id')} uses the wrong additional code" unless review['additional_code'] == expected_code
      end
      exclusions.each { |item| item.fetch('review').fetch('disposition') }
    end

    def build_rule_paths(paths)
      RULE_DEFINITIONS.flat_map do |family_id, definition|
        source_paths = paths.select { |path| path['journey_id'] == definition.fetch('source_journey_id') }
        raise BuildError, "rule family #{family_id} has no source paths" if source_paths.empty?

        source_paths.map { |source_path| build_rule_path(source_path, family_id, definition) }
      end
    end

    def build_rule_path(source_path, family_id, definition)
      subject = {
        'source_answer_path_subject_sha256' => source_path.fetch('subject_sha256'),
        'rule_family_id' => family_id,
        'definition' => definition,
      }
      rule_path = source_path.deep_dup.merge(
        'id' => "rule-path:#{sha256(subject)}",
        'subject_sha256' => sha256(subject),
        'source_answer_path_id' => source_path.fetch('id'),
        'source_journey_id' => source_path.fetch('journey_id'),
        'journey_id' => family_id,
        'scope' => rule_scope(source_path, family_id, definition),
      )
      normalise_rule_review!(rule_path, definition)
      rule_path
    end

    def rule_scope(source_path, family_id, definition)
      {
        'type' => 'rule_family',
        'rule_family_id' => family_id,
        'origin' => definition.fetch('origin'),
        'source_journey_id' => definition.fetch('source_journey_id'),
        'source_packet_id' => source_path.fetch('source_packet_id'),
        'restricted_commodity_codes' => definition['restricted_commodity_codes'],
      }
    end

    def normalise_rule_review!(rule_path, definition)
      treatment = rule_path.dig('terminal', 'treatment')
      has_measure_mapping = definition.fetch('measure_ids').any?
      if treatment.present? && treatment != 'standard' && has_measure_mapping
        rule_path['review'] = {
          'kind' => 'connection_candidate',
          'status' => 'pending_domain_review',
          'treatment' => treatment,
          'additional_code' => QuestionJourneyContract::TREATMENTS.dig(treatment, 'additional_code'),
          'quote_support' => rule_path.dig('review', 'quote_support'),
        }
      elsif treatment.present? && treatment != 'standard'
        rule_path['review'] = {
          'kind' => 'disposition',
          'status' => 'spike_recorded',
          'disposition' => 'no_relief_connection_for_this_rule',
          'reason' => 'This extracted exception rule has no independent non-standard tariff-measure ending.',
          'quote_support' => rule_path.dig('review', 'quote_support'),
        }
      end
    end

    def build_connection_proposals(rule_paths)
      proposals = RULE_DEFINITIONS.flat_map do |family_id, definition|
        measure_ids = definition.fetch('measure_ids')
        next [] if measure_ids.empty?

        candidate_paths = rule_paths.select do |path|
          path['journey_id'] == family_id && path.dig('review', 'kind') == 'connection_candidate'
        end
        raise BuildError, "rule family #{family_id} has no connection path" if candidate_paths.empty?

        candidate_paths.product(measure_ids).map do |path, measure_id|
          build_connection_proposal(path, measure_by_id(measure_id), definition)
        end
      end
      proposals.sort_by { |proposal| proposal.fetch('id') }
    end

    def build_connection_proposal(path, measure_snapshot, definition)
      evidence_for = {
        'guidance' => path.dig('terminal', 'evidence'),
        'tariff_finding' => "Pinned measure #{measure_snapshot.fetch('measure_id')} offers #{measure_snapshot.fetch('additional_code')} to every listed declarable descendant of #{measure_snapshot.fetch('origin_goods_nomenclature')}.",
      }
      evidence_against = {
        'wrong_relief_persona' => WRONG_RELIEF_CHALLENGES.fetch(path.fetch('journey_id')),
        'assessment' => 'The counterexample can honestly use the commodity classification while declining at least one condition in this exact rule path. Availability therefore cannot prove eligibility.',
        'declarable_cohort_reviewed' => measure_snapshot.fetch('declarable_commodity_codes'),
      }
      restricted_codes = definition['restricted_commodity_codes']
      if restricted_codes
        evidence_against['restricted_connection_scope'] = restricted_codes
        measure_snapshot = measure_snapshot.merge(
          'declarable_commodity_codes' => measure_snapshot.fetch('declarable_commodity_codes') & restricted_codes,
          'full_inherited_declarable_cohort' => measure_snapshot.fetch('declarable_commodity_codes'),
        )
      end
      subject = {
        'answer_path_subject_sha256' => path.fetch('subject_sha256'),
        'answer_path_id' => path.fetch('id'),
        'journey_id' => path.fetch('journey_id'),
        'treatment' => path.dig('terminal', 'treatment'),
        'measure_snapshot' => measure_snapshot,
        'evidence_for' => evidence_for,
        'evidence_against' => evidence_against,
      }
      subject_sha256 = ReviewDecisionContract.proposal_subject_sha256(subject)
      proposal_id = "connection-proposal:#{subject_sha256}"
      path.fetch('review')['measure_binding_status'] = 'pinned_proposal_available'
      path.fetch('review')['measure_connection_proposal_ids'] ||= []
      path.fetch('review')['measure_connection_proposal_ids'] << proposal_id
      {
        'id' => proposal_id,
        'subject_sha256' => subject_sha256,
        'status' => 'pending_domain_review',
        **subject,
        'pairing_approval' => pending_approval('Does this exact rule path correctly pair with this measure and its complete inherited commodity cohort?'),
        'quote_support_approval' => pending_approval('Does the cited evidence entail this complete terminal path?'),
      }
    end

    def measure_by_id(measure_id)
      measure = tariff_snapshot.fetch('measures').find { |item| item['measure_id'] == measure_id }
      raise BuildError, "missing pinned measure #{measure_id}" unless measure

      measure.merge('snapshot_date' => tariff_snapshot.fetch('snapshot_date'))
    end

    def build_composed_journeys(paths, connection_proposals, spike_reviews)
      tariff_snapshot.fetch('commodity_measure_inventory').map do |inventory|
        commodity_code = inventory.fetch('commodity_code')
        measure_ids = inventory.fetch('applicable_non_standard_measure_ids')
        rule_order = composition_rule_order(commodity_code, measure_ids)

        CommodityJourneyComposer.new(
          commodity_code: commodity_code,
          rule_order: rule_order,
          paths: paths,
          connection_proposals: connection_proposals,
          review_decisions: spike_reviews,
          applicable_measure_ids: measure_ids,
          mode: :spike,
        ).call
      end
    end

    def composition_rule_order(commodity_code, measure_ids)
      rules = []
      rules << COMMODITY_SPECIFIC_RULES[commodity_code] if COMMODITY_SPECIFIC_RULES.key?(commodity_code)
      measure_ids.each do |measure_id|
        family_id = RULE_DEFINITIONS.find { |_id, definition| definition.fetch('measure_ids').include?(measure_id) }&.first
        raise BuildError, "no rule family covers applicable measure #{measure_id}" unless family_id

        rules << family_id
      end
      rules.uniq
    end

    def pending_approval(decision_scope)
      {
        'status' => 'pending_domain_review',
        'reviewer' => nil,
        'reviewed_at' => nil,
        'decision_scope' => decision_scope,
      }
    end

    def sha256(value)
      Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(value))
    end

    def build_summary(paths, exclusions, connection_proposals, spike_reviews, composed_journeys)
      outcomes = paths.count { |path| path.dig('terminal', 'type') == 'outcome' }
      fallthroughs = paths.count { |path| path.dig('terminal', 'type') == 'fallthrough' }
      treatment_counts = paths.filter_map { |path| path.dig('terminal', 'treatment') }.tally.sort.to_h
      {
        'answer_paths' => paths.size,
        'section_packets_accounted_for' => question_journeys.dig('summary', 'packet_review_records_accounted_for'),
        'section_packets_without_safe_tree' => question_journeys.fetch('packet_review_records').count do |record|
          record['status'] == 'no_contract_safe_tree_identified'
        end,
        'outcome_paths' => outcomes,
        'fallthrough_paths' => fallthroughs,
        'exclusions' => exclusions.size,
        'treatment_paths' => treatment_counts,
        'connection_candidates' => paths.count { |path| path.dig('review', 'kind') == 'connection_candidate' },
        'rule_connection_paths' => connection_proposals.pluck('answer_path_id').uniq.size,
        'pinned_measure_proposals' => connection_proposals.size,
        'approved_measure_connections' => connection_proposals.count { |proposal| proposal['status'] == 'approved' },
        'synthetic_pairing_approvals' => spike_reviews.fetch('pairing_decisions').count { |decision| decision['status'] == 'spike_approved' },
        'synthetic_quote_support_approvals' => spike_reviews.fetch('quote_support_decisions').count { |decision| decision['status'] == 'spike_approved' },
        'composed_spike_commodities' => composed_journeys.size,
        'dispositions' => paths.count { |path| path.dig('review', 'kind') == 'disposition' } + exclusions.size,
        'pending_quote_support_reviews' => paths.size + exclusions.size,
        'notices' => paths.filter_map { |path| path.dig('scope', 'notice_number') }.uniq.sort,
        'commodity_codes' => composed_journeys.pluck('commodity_code').sort,
      }
    end
  end
end
