RSpec.describe VatGuidance::CommodityJourneyComposer do
  subject(:composition) { build_composer.call }

  let(:artifact) do
    VatGuidance::HmrcPocArtifactBuilder.new(
      poc_artifact('context_graph.json'),
      poc_artifact('context_packets.json'),
      poc_artifact('question_journeys.json'),
    ).call
  end
  let(:paths) { artifact.fetch('rule_paths') }
  let(:proposals) { artifact.fetch('measure_connection_proposals') }
  let(:reviews) { artifact.fetch('synthetic_spike_reviews') }

  it 'composes every rule path and permits standard only after exact measure exhaustion' do
    expect(composition).to include(
      'commodity_code' => '6506101000',
      'status' => 'spike_simulation_complete',
      'production_eligible' => false,
    )
    expect(composition.fetch('resolved_answer_paths').size).to eq(6)
    expect(composition.fetch('resolved_answer_paths').pluck('treatment').tally).to eq(
      'standard' => 5,
      'zero' => 1,
    )
    expect(composition.fetch('resolved_answer_paths').pluck('resolution')).not_to include('fallthrough')
    expect(composition.fetch('exhaustion_note')).to include(
      'applicable_non_standard_measure_ids' => ['-1012552782'],
      'covered_measure_ids' => ['-1012552782'],
      'standard_by_default_permitted_after_all_rules_decline' => true,
    )
  end

  it 'composes the full inherited declarable cohort without cross-code leakage' do
    sibling = build_composer(commodity_code: '6506108000').call

    expect(sibling.fetch('commodity_code')).to eq('6506108000')
    expect { build_composer(commodity_code: '6506999090').call }.to raise_error(
      described_class::CompositionError,
      'no connection proposal covers 6506999090',
    )
  end

  it 'fails closed when quote support is missing or stale' do
    missing_reviews = reviews.deep_dup
    relevant_path = paths.find do |path|
      path['journey_id'] == 'rule-family:industrial-protective-equipment'
    end
    missing_reviews.fetch('quote_support_decisions').reject! do |decision|
      decision['subject_id'] == relevant_path.fetch('id')
    end
    expect { build_composer(review_decisions: missing_reviews).call }.to raise_error(
      described_class::CompositionError,
      /missing quote-support decision/,
    )

    fresh_reviews = reviews.deep_dup
    paths.find { |path| path['journey_id'] == 'rule-family:industrial-protective-equipment' }
         .fetch('steps').first['question'] = 'Changed after synthetic review'
    expect { build_composer(review_decisions: fresh_reviews).call }.to raise_error(
      described_class::CompositionError,
      /stale quote-support decision/,
    )
  end

  it 'fails closed when the applicable measure set is not covered exactly' do
    expect { build_composer(applicable_measure_ids: %w[-1012552782 missing-measure]).call }.to raise_error(
      described_class::CompositionError,
      /measure exhaustion mismatch/,
    )
  end

  it 'rejects a review decision changed after it was recorded' do
    tampered_reviews = reviews.deep_dup
    decision = tampered_reviews.fetch('pairing_decisions').find do |item|
      proposals.find { |proposal| proposal['id'] == item['subject_id'] }
               &.dig('measure_snapshot', 'measure_id') == '-1012552782'
    end
    decision['reviewer'] = 'someone-else'

    expect { build_composer(review_decisions: tampered_reviews).call }.to raise_error(
      described_class::CompositionError,
      /tampered pairing decision/,
    )
  end

  it 'rejects a proposal changed after its exact path-measure approval' do
    changed_proposals = proposals.deep_dup
    proposal = changed_proposals.find { |item| item.dig('measure_snapshot', 'measure_id') == '-1012552782' }
    proposal.fetch('measure_snapshot')['additional_code'] = 'VATR'

    expect { build_composer(connection_proposals: changed_proposals).call }.to raise_error(
      described_class::CompositionError,
      /tampered proposal/,
    )
  end

  it 'refuses to borrow another path approval when an exact proposal is absent' do
    chapter_20 = artifact.fetch('composed_commodity_journeys').find { |journey| journey['commodity_code'] == '2008939120' }
    rule_order = chapter_20.fetch('rule_order')
    relevant_paths = paths.select { |path| rule_order.include?(path.fetch('journey_id')) }
    exact_path = relevant_paths.find { |path| path.dig('terminal', 'treatment') == 'zero' }
    reduced_proposals = proposals.reject { |proposal| proposal['answer_path_id'] == exact_path.fetch('id') }

    expect {
      described_class.new(
        commodity_code: '2008939120',
        rule_order: rule_order,
        paths: paths,
        connection_proposals: reduced_proposals,
        review_decisions: reviews,
        applicable_measure_ids: ['-1012550520'],
      ).call
    }.to raise_error(described_class::CompositionError, /no exact approved connection/)
  end

  it 'continues a declining path into the next ordered rule before resolving it' do
    chapter_20 = artifact.fetch('composed_commodity_journeys').find { |journey| journey['commodity_code'] == '2005202000' }
    continued = chapter_20.fetch('resolved_answer_paths').select { |route| route.fetch('component_path_ids').size == 2 }

    expect(continued).not_to be_empty
    expect(continued).to all(satisfy { |route| route.fetch('steps').size == 3 })
    expect(chapter_20.fetch('resolved_answer_paths')).not_to include(
      satisfy { |route| route['resolution'] == 'exhausted_relief_rules' },
    )
  end

  it 'rejects synthetic approvals in production mode' do
    expect { build_composer(mode: :production).call }.to raise_error(
      described_class::CompositionError,
      'production composition rejects synthetic review decisions',
    )
  end

  it 'accepts the same contract when authorised human decisions replace the spike fixture' do
    production_reviews = reviews.deep_dup
    production_reviews['review_mode'] = VatGuidance::ReviewDecisionContract::AUTHORISED_MODE
    production_reviews['production_eligible'] = true
    decisions = production_reviews.fetch('pairing_decisions') + production_reviews.fetch('quote_support_decisions')
    decisions.each do |decision|
      decision['status'] = VatGuidance::ReviewDecisionContract::PRODUCTION_APPROVAL
      decision['review_mode'] = VatGuidance::ReviewDecisionContract::AUTHORISED_MODE
      decision['reviewer'] = 'tax-content:test-authorised-reviewer'
      decision['decision_sha256'] = VatGuidance::ReviewDecisionContract.decision_sha256(decision)
    end

    result = build_composer(review_decisions: production_reviews, mode: :production).call

    expect(result).to include('status' => 'approved', 'production_eligible' => true)
  end

  def build_composer(commodity_code: '6506101000', applicable_measure_ids: ['-1012552782'],
                     review_decisions: reviews, connection_proposals: proposals, mode: :spike)
    described_class.new(
      commodity_code: commodity_code,
      rule_order: %w[rule-family:industrial-protective-equipment],
      paths: paths,
      connection_proposals: connection_proposals,
      review_decisions: review_decisions,
      applicable_measure_ids: applicable_measure_ids,
      mode: mode,
    )
  end

  def poc_artifact(filename)
    JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance', filename)))
  end
end
