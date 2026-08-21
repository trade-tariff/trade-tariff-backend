RSpec.describe VatGuidance::HmrcPocArtifactBuilder do
  subject(:artifact) { described_class.new(context_graph, context_packets, question_journeys).call }

  let(:context_graph) { poc_artifact('context_graph.json') }
  let(:context_packets) { poc_artifact('context_packets.json') }
  let(:question_journeys) do
    poc_artifact('question_journeys.json')
  end

  it 'builds a complete, deterministic, explicitly non-production spike artifact' do
    expect(artifact.dig('summary', 'answer_paths')).to eq(53)
    expect(artifact.dig('summary', 'section_packets_accounted_for')).to eq(148)
    expect(artifact.dig('summary', 'section_packets_without_safe_tree')).to eq(137)
    expect(artifact.dig('summary', 'connection_candidates')).to eq(3)
    expect(artifact.dig('summary', 'rule_connection_paths')).to eq(11)
    expect(artifact.dig('summary', 'pinned_measure_proposals')).to eq(12)
    expect(artifact.dig('summary', 'approved_measure_connections')).to eq(0)
    expect(artifact.dig('summary', 'synthetic_pairing_approvals')).to eq(12)
    expect(artifact.dig('summary', 'synthetic_quote_support_approvals')).to eq(105)
    expect(artifact.dig('summary', 'composed_spike_commodities')).to eq(11)
    expect(artifact.dig('summary', 'dispositions')).to eq(54)
    expect(artifact.dig('summary', 'pending_quote_support_reviews')).to eq(57)
    expect(artifact.dig('spike_status', 'workflow_demo_ready')).to be(true)
    expect(artifact.dig('spike_status', 'mapping_review_ready')).to be(true)
    expect(artifact.dig('spike_status', 'end_to_end_simulation_ready')).to be(true)
    expect(artifact.dig('spike_status', 'hmrc_demo_ready')).to be(false)
    expect(artifact.dig('spike_status', 'production_ready')).to be(false)
    expect(artifact.dig('spike_status', 'runtime_approved')).to be(false)
    expect(described_class.new(context_graph.deep_dup, context_packets.deep_dup, question_journeys.deep_dup).call).to eq(artifact)
  end

  it 'retains an explicit disposition or curated journey for every section packet' do
    records = artifact.fetch('section_packet_reviews')

    expect(records.size).to eq(148)
    expect(records.pluck('packet_id').uniq.size).to eq(148)
    expect(records.pluck('status').tally).to eq(
      'journey_curated' => 11,
      'no_contract_safe_tree_identified' => 137,
    )
    expect(records).to all(satisfy do |record|
      accounted = record.fetch('journey_ids').present? || record.fetch('finding').present?
      record.fetch('source_packet_sha256').match?(/\A[0-9a-f]{64}\z/) && accounted
    end)
  end

  it 'creates a synthetic quote-review subject for every source terminal and exclusion' do
    reviewed_ids = artifact.dig('synthetic_spike_reviews', 'quote_support_decisions').pluck('subject_id')
    source_ids = artifact.fetch('answer_paths').pluck('id') + artifact.fetch('exclusions').pluck('id')

    expect(reviewed_ids).to include(*source_ids)
    expect(source_ids.size).to eq(57)
  end

  it 'pins a real safety-headgear measure proposal without claiming approval or eligibility' do
    proposal = artifact.fetch('measure_connection_proposals').find do |item|
      item.dig('measure_snapshot', 'measure_id') == '-1012552782'
    end
    composition = artifact.fetch('composed_commodity_journeys').find do |item|
      item['commodity_code'] == '6506101000'
    end

    expect(proposal).to include(
      'treatment' => 'zero',
      'status' => 'pending_domain_review',
    )
    expect(proposal.fetch('measure_snapshot')).to include(
      'measure_id' => '-1012552782',
      'additional_code' => 'VATZ',
      'origin_goods_nomenclature' => '6506100000',
      'declarable_commodity_codes' => %w[6506101000 6506108000],
    )
    expect(proposal.dig('pairing_approval', 'reviewer')).to be_nil
    expect(proposal.dig('quote_support_approval', 'status')).to eq('pending_domain_review')
    proposed_path = artifact.fetch('rule_paths').find { |path| path.fetch('id') == proposal.fetch('answer_path_id') }
    expect(proposed_path.fetch('review')).to include(
      'measure_binding_status' => 'pinned_proposal_available',
      'measure_connection_proposal_ids' => [proposal.fetch('id')],
    )
    expect(composition).to include('status' => 'spike_simulation_complete', 'production_eligible' => false)
    expect(composition.dig('exhaustion_note', 'standard_by_default_permitted_after_all_rules_decline')).to be(true)
  end

  it 'maps only non-standard outcomes to their provisional national additional code' do
    candidates = artifact.fetch('answer_paths').select { |path| path.dig('review', 'kind') == 'connection_candidate' }

    expect(candidates).to all(satisfy do |path|
      expected = VatGuidance::QuestionJourneyContract::TREATMENTS.dig(path.dig('terminal', 'treatment'), 'additional_code')
      path.dig('review', 'additional_code') == expected && expected.present?
    end)
    expect(artifact.fetch('answer_paths').select { |path| path.dig('terminal', 'treatment') == 'standard' }).to all(
      satisfy { |path| path.dig('review', 'kind') == 'disposition' },
    )
  end

  it 'binds every proposal to its exact rule path and compatible treatment code' do
    rule_paths = artifact.fetch('rule_paths').index_by { |path| path.fetch('id') }

    artifact.fetch('measure_connection_proposals').each do |proposal|
      path = rule_paths.fetch(proposal.fetch('answer_path_id'))
      expected_code = VatGuidance::QuestionJourneyContract::TREATMENTS.dig(
        path.dig('terminal', 'treatment'),
        'additional_code',
      )
      expect(proposal.fetch('subject_sha256')).to eq(
        VatGuidance::ReviewDecisionContract.proposal_subject_sha256(proposal),
      )
      expect(proposal.dig('measure_snapshot', 'additional_code')).to eq(expected_code)
    end
  end

  it 'completes exact exhaustion for every scoped spike commodity' do
    notes = artifact.fetch('commodity_exhaustion_notes')

    expect(notes.pluck('commodity_code')).to eq(
      %w[2005202000 2008939120 2008979890 6506101000 6506108000 8407100010 8409100010 8409100020 8409100090 8424100011 9401800000],
    )
    expect(notes).to all(include('standard_by_default_permitted_after_all_rules_decline' => true))
    expect(notes).to all(include('status' => 'complete_for_pinned_spike_snapshot'))
  end

  it 'pins the complete inherited cohorts for every scoped non-standard measure' do
    snapshots = artifact.fetch('measure_connection_proposals').pluck('measure_snapshot')
    snapshots = snapshots.uniq { |measure| measure.fetch('measure_id') }
    snapshots = snapshots.index_by { |measure| measure.fetch('measure_id') }

    expect(snapshots.transform_values { |measure| measure.fetch('full_inherited_declarable_cohort', measure.fetch('declarable_commodity_codes')).size }).to include(
      '-1012549006' => 1,
      '-1012552782' => 2,
      '-1012550499' => 36,
      '-1012550520' => 309,
      '-1012986553' => 1,
      '-1012984751' => 3,
      '-1012980985' => 1,
    )
    expect(snapshots.fetch('-1012550520').fetch('full_inherited_declarable_cohort')).to include(
      '2008939120',
      '2008979890',
    )
  end

  it 'composes every Chapter 20 and Chapter 84 commodity with no unresolved terminal' do
    compositions = artifact.fetch('composed_commodity_journeys').index_by { |journey| journey.fetch('commodity_code') }
    scoped_codes = %w[2005202000 2008939120 2008979890 8407100010 8409100090 8424100011]

    expect(compositions.keys).to include(*scoped_codes)
    scoped_codes.each do |commodity_code|
      composition = compositions.fetch(commodity_code)
      exhaustion = composition.fetch('exhaustion_note')
      expect(composition.fetch('resolved_answer_paths')).to all(
        satisfy { |path| %w[standard zero].include?(path.fetch('treatment')) },
      )
      expect(exhaustion.fetch('covered_measure_ids')).to eq(exhaustion.fetch('applicable_non_standard_measure_ids'))
      expect(exhaustion.fetch('standard_by_default_permitted_after_all_rules_decline')).to be(true)
    end

    chapter_20 = compositions.values_at('2005202000', '2008939120', '2008979890')
    expect(chapter_20).to all(satisfy do |composition|
      composition.fetch('resolved_answer_paths').any? { |route| route.fetch('component_path_ids').size == 2 }
    end)
    chapter_84 = compositions.values_at('8407100010', '8409100090', '8424100011')
    expect(chapter_84).to all(satisfy do |composition|
      composition.fetch('resolved_answer_paths').count { |path| path['resolution'] == 'synthetic_spike_rule_connections' } == 2
    end)
  end

  it 'accounts for every generated notice rule while keeping comparison and out-of-scope paths dispositioned' do
    rule_paths = artifact.fetch('rule_paths')
    notice_paths = rule_paths.select { |path| path.fetch('source_journey_id').start_with?('notice-') }

    expect(notice_paths.pluck('source_journey_id').sort).to include(
      'notice-701-14-food-exceptions',
      'notice-701-23-child-car-seats',
      'notice-701-23-industrial-protective-equipment',
    )
    expect(notice_paths).to all(satisfy do |path|
      %w[connection_candidate disposition].include?(path.dig('review', 'kind'))
    end)
    child_reduced = notice_paths.find do |path|
      path.fetch('source_journey_id') == 'notice-701-23-child-car-seats' && path.dig('terminal', 'treatment') == 'reduced'
    end
    expect(child_reduced.fetch('review')).to include('kind' => 'connection_candidate', 'additional_code' => 'VATR')
    expect(artifact.fetch('measure_connection_proposals')).to include(
      satisfy { |proposal| proposal.dig('measure_snapshot', 'measure_id') == '-1012549006' },
    )
    expect(artifact.fetch('measure_connection_proposals')).to all(
      satisfy { |proposal| !proposal.fetch('journey_id').include?('catering-') },
    )
  end

  it 'rejects drift in the pinned tariff snapshot' do
    tariff_snapshot = poc_artifact('spike_tariff_snapshot.json')
    tariff_snapshot.fetch('measures').first.fetch('declarable_commodity_codes') << '9999999999'

    expect {
      described_class.new(context_graph, context_packets, question_journeys, tariff_snapshot).call
    }.to raise_error(described_class::BuildError, 'spike tariff snapshot content hash is invalid')
  end

  it 'rejects a hash-valid tariff snapshot with invalid VAT semantics or incomplete inventory' do
    tariff_snapshot = poc_artifact('spike_tariff_snapshot.json')
    tariff_snapshot.fetch('measures').first['measure_type_id'] = '999'
    refresh_content_hash!(tariff_snapshot)
    expect {
      described_class.new(context_graph, context_packets, question_journeys, tariff_snapshot).call
    }.to raise_error(described_class::BuildError, /not UK VAT measure type 305/)

    tariff_snapshot = poc_artifact('spike_tariff_snapshot.json')
    tariff_snapshot.fetch('commodity_measure_inventory').first.fetch('applicable_non_standard_measure_ids').clear
    refresh_content_hash!(tariff_snapshot)
    expect {
      described_class.new(context_graph, context_packets, question_journeys, tariff_snapshot).call
    }.to raise_error(described_class::BuildError, /has no non-standard VAT measures/)

    tariff_snapshot = poc_artifact('spike_tariff_snapshot.json')
    tariff_snapshot.fetch('measures').first.fetch('declarable_commodity_codes') << '9999999999'
    tariff_snapshot.fetch('measures').first.fetch('declarable_commodity_codes').sort!
    refresh_content_hash!(tariff_snapshot)
    expect {
      described_class.new(context_graph, context_packets, question_journeys, tariff_snapshot).call
    }.to raise_error(described_class::BuildError, /cohort evidence hash is invalid/)
  end

  it 'creates connections from explicit rule definitions, never from commodity journeys' do
    proposals = artifact.fetch('measure_connection_proposals')

    expect(proposals).to all(satisfy { |proposal| proposal.fetch('journey_id').start_with?('rule-family:') })
    expect(proposals).to all(satisfy do |proposal|
      proposal.fetch('evidence_against').fetch('wrong_relief_persona').length > 80
    end)
    expect(proposals).to all(satisfy do |proposal|
      path = artifact.fetch('rule_paths').find { |item| item['id'] == proposal['answer_path_id'] }
      path.dig('scope', 'type') == 'rule_family'
    end)
  end

  it 'rejects source drift instead of inheriting stale path reviews' do
    question_journeys['journeys'].first['questions'].first['prompt'] = 'Changed after validation'

    expect { artifact }.to raise_error(described_class::BuildError, 'question journey artifact content hash is invalid')
  end

  it 'rejects a broken graph-to-packet-to-journey lineage' do
    context_packets['source_graph_sha256'] = '0' * 64
    refresh_content_hash!(context_packets)

    expect { artifact }.to raise_error(
      described_class::BuildError,
      'context packet artifact is not bound to the supplied context graph',
    )
  end

  it 'rejects tampered graph or packet content even when cross-links are unchanged' do
    context_graph.fetch('summary')['sections_captured'] = -1
    expect { artifact }.to raise_error(described_class::BuildError, 'context graph content hash is invalid')

    fresh_graph = poc_artifact('context_graph.json')
    context_packets.fetch('summary')['packets'] = -1
    expect {
      described_class.new(fresh_graph, context_packets, question_journeys).call
    }.to raise_error(described_class::BuildError, 'context packet artifact content hash is invalid')
  end

  it 'retains the safety-headgear wrong-relief signpost without claiming it is covered' do
    assessment = artifact.fetch('signpost_assessments').sole

    expect(assessment).to include(
      'commodity_code' => '6506101000',
      'status' => 'end_to_end_spike_simulated_pending_real_review',
    )
  end

  def refresh_content_hash!(value)
    content = value.except('content_sha256')
    value['content_sha256'] = Digest::SHA256.hexdigest(JSON.generate(deep_sort(content)))
  end

  def deep_sort(value)
    case value
    when Hash then value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
    when Array then value.map { |item| deep_sort(item) }
    else value
    end
  end

  def poc_artifact(filename)
    JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance', filename)))
  end
end
