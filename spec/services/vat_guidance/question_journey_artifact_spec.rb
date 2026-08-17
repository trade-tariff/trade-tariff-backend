RSpec.describe 'generated VAT guidance question journeys' do
  subject(:artifact) { JSON.parse(File.read(artifact_path)) }

  let(:artifact_path) { Rails.root.join('data/vat_guidance/question_journeys.json') }
  let(:packets_path) { Rails.root.join('data/vat_guidance/context_packets.json') }
  let(:candidates_path) { Rails.root.join('data/vat_guidance/question_journey_candidates.json') }

  it 'passes the deterministic contract for every committed journey' do
    reports = artifact.fetch('validation_reports')

    expect(reports).not_to be_empty
    expect(reports).to all(include('valid' => true, 'errors' => []))
    expect(artifact.dig('summary', 'invalid_journeys')).to be_zero
  end

  it 'covers all three target notices and both requested commodity chapters' do
    expect(artifact.dig('summary', 'notices_covered')).to eq(%w[701/14 701/23 709/1])
    expect(artifact.dig('summary', 'commodity_chapters')).to eq(%w[20 84])
    expect(artifact.dig('summary', 'commodity_journeys')).to eq(6)
    expect(artifact.dig('summary', 'commodity_codes')).to eq(
      %w[2005202000 2008939120 2008979890 8407100010 8409100090 8424100011],
    )
  end

  it 'contains a journey for every curated Chapter 20 and Chapter 84 commodity packet' do
    packets = JSON.parse(File.read(packets_path))
    expected_codes = packets.fetch('commodity_packets').map { |packet| packet.dig('source', 'commodity_code') }.sort
    actual_codes = artifact.fetch('journeys').filter_map { |journey| journey.dig('scope', 'commodity_code') }.sort

    expect(actual_codes).to eq(expected_codes)
  end

  it 'commits every generated journey with the complete composition contract' do
    expect(artifact.fetch('journeys')).to all(
      include(
        'relief_rule_ids' => be_an(Array),
        'composition_required' => be(true).or(be(false)),
        'fallthrough_targets' => be_an(Array),
      ),
    )
  end

  it 'does not standard-rate prepared fruit that may still be fit for animal consumption' do
    journey = artifact.fetch('journeys').find do |candidate|
      candidate['journey_id'] == 'commodity-2008979890-prepared-fruit-mixtures'
    end
    questions = journey.fetch('questions').index_by { |question| question.fetch('id') }

    expect(questions.fetch('fruit-human-food').fetch('answers').find { |answer| answer['id'] == 'no' }).to include(
      'next' => include('type' => 'fallthrough'),
    )
    expect(questions.fetch('fruit-fit-human').fetch('answers').find { |answer| answer['id'] == 'no' }).to include(
      'next' => include('type' => 'question', 'id' => 'fruit-fit-animal'),
    )
    expect(questions.fetch('fruit-fit-animal').fetch('answers').find { |answer| answer['id'] == 'yes' }).to include(
      'next' => include('type' => 'fallthrough'),
    )
    expect(questions.fetch('fruit-fit-animal').fetch('answers').find { |answer| answer['id'] == 'no' }).to include(
      'next' => include('type' => 'outcome', 'id' => 'fruit-standard-not-food'),
    )
  end

  it 'binds the generated candidates and artifact to the committed packet and prompt versions' do
    packets = JSON.parse(File.read(packets_path))
    candidates = JSON.parse(File.read(candidates_path))

    expect(candidates.fetch('source_packets_sha256')).to eq(packets.fetch('content_sha256'))
    expect(candidates.dig('generation_metadata', 'prompt_sha256')).to eq(
      Digest::SHA256.hexdigest(VatGuidance::QuestionJourneyContract.generation_prompt),
    )
    expect(artifact.fetch('source_packets_sha256')).to eq(packets.fetch('content_sha256'))
    expect(artifact.fetch('content_sha256')).to eq(VatGuidance::QuestionJourneyArtifactBuilder.content_sha256(artifact))
    expect(artifact.fetch('runtime_approved')).to be(false)
    expect(artifact.fetch('human_review_status')).to eq('required')
  end

  it 'is a fresh deterministic rebuild of the committed candidates' do
    rebuilt = VatGuidance::QuestionJourneyArtifactBuilder.new(
      JSON.parse(File.read(packets_path)),
      JSON.parse(File.read(candidates_path)),
    ).call

    expect(rebuilt).to eq(artifact)
  end

  it 'fails fast when candidate provenance has drifted' do
    packets = JSON.parse(File.read(packets_path))
    candidates = JSON.parse(File.read(candidates_path))
    candidates['source_packets_sha256'] = 'stale'

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /source packet hash has drifted/,
    )
  end

  it 'recomputes packet hashes instead of trusting declared provenance' do
    packets = JSON.parse(File.read(packets_path))
    candidates = JSON.parse(File.read(candidates_path))
    packets.fetch('packets').first.fetch('content').first['text'] = 'Injected replacement guidance'

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /context packet artifact content hash is invalid/,
    )
  end

  it 'rejects duplicate journeys and comparison roles bound to the wrong packet' do
    packets = JSON.parse(File.read(packets_path))
    candidates = JSON.parse(File.read(candidates_path))
    candidates.fetch('journeys') << candidates.fetch('journeys').first.deep_dup

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /journey ids must be present and unique/,
    )

    candidates = JSON.parse(File.read(candidates_path))
    local = candidates.fetch('journeys').find { |journey| journey['comparison_role'] == 'catering_local_only' }
    old_packet_id = local.fetch('source_packet_id')
    new_packet_id = candidates.fetch('journeys').first.fetch('source_packet_id')
    local['source_packet_id'] = new_packet_id
    attempts = candidates.fetch('packet_review_records').index_by { |attempt| attempt.fetch('packet_id') }
    attempts.fetch(new_packet_id).fetch('journey_ids') << local.fetch('journey_id')
    attempts.fetch(old_packet_id).merge!(
      'status' => 'no_contract_safe_tree_identified',
      'journey_ids' => [],
      'finding' => 'Test disposition',
    )

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /local-only journey uses the wrong packet/,
    )
  end

  it 'rejects stored numerical rates anywhere outside evidence quotes' do
    ['20 percent', 'fifteen percent', 'half per cent', '½%'].each do |stored_rate|
      packets = JSON.parse(File.read(packets_path))
      candidates = JSON.parse(File.read(candidates_path))
      candidates.fetch('spike_findings').first['finding'] = "Assume #{stored_rate}"

      expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
        VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
        /stores a numerical percentage/,
      )
    end
  end

  it 'does not force unsupported zero rating when packaged-crisps conditions fail' do
    journey = artifact.fetch('journeys').find { |item| item.dig('scope', 'commodity_code') == '2005202000' }
    question = journey.fetch('questions').find { |item| item.fetch('id') == 'crisps-packaged-ready' }
    declined = question.fetch('answers').find { |answer| answer.fetch('id') == 'no' }

    expect(declined.fetch('next')).to include(
      'type' => 'fallthrough',
      'trader_visible' => false,
      'id' => 'next-applicable-rule',
    )
    expect(journey.fetch('outcomes').pluck('id')).not_to include('crisps-zero-other')
  end

  it 'accounts for every reviewed source packet without claiming an LLM generated every section' do
    coverage = artifact.fetch('packet_generation_coverage')

    expect(coverage.size).to eq(141)
    expect(coverage.pluck('notice_number').uniq.sort).to eq(%w[701/14 701/23 709/1])
    expect(coverage.pluck('status').uniq).to contain_exactly('journey_curated', 'no_contract_safe_tree_identified')
    expect(artifact.fetch('packet_review_records').pluck('method').uniq).to eq(%w[ai_assisted_human_review])
    expect(artifact.fetch('packet_review_records').size).to eq(148)
    expect(artifact.dig('summary', 'packet_review_records')).to eq(148)
    expect(artifact.dig('summary', 'packet_review_records_accounted_for')).to eq(148)
    expect(artifact.dig('summary', 'target_notice_packets_accounted_for')).to eq(141)
    expect(artifact.dig('summary', 'target_notice_packets_with_journeys')).to be < 141
  end

  it 'requires a hash-bound review record for every input packet' do
    packets = JSON.parse(File.read(packets_path))
    candidates = JSON.parse(File.read(candidates_path))
    candidates.fetch('packet_review_records').pop

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /missing packet review records/,
    )

    candidates = JSON.parse(File.read(candidates_path))
    candidates.fetch('packet_review_records').first['source_packet_sha256'] = 'stale'

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /source hash has drifted/,
    )
  end

  it 'does not allow generation coverage to claim a journey that is absent' do
    packets = JSON.parse(File.read(packets_path))
    candidates = JSON.parse(File.read(candidates_path))
    attempt = candidates.fetch('packet_review_records').find do |item|
      item['status'] == 'no_contract_safe_tree_identified'
    end
    attempt.merge!('status' => 'journey_curated', 'journey_ids' => %w[invented], 'finding' => nil)

    expect { VatGuidance::QuestionJourneyArtifactBuilder.new(packets, candidates).call }.to raise_error(
      VatGuidance::QuestionJourneyArtifactBuilder::BuildError,
      /does not match generated journeys/,
    )
  end

  it 'uses complete, explicit qualifying-aircraft questions in every Chapter 84 journey' do
    aviation_journeys = artifact.fetch('journeys').select { |journey| journey.dig('scope', 'chapter') == '84' }

    aviation_journeys.each do |journey|
      prompts = journey.fetch('questions').pluck('prompt').join(' ')
      expect(prompts).to include('state institution', '8,000kg', 'recreation or pleasure')
    end
  end

  it 'uses only complete commodity packets with no unresolved references or omissions' do
    packets = JSON.parse(File.read(packets_path)).fetch('commodity_packets')

    expect(packets).to all(include('unresolved_references' => [], 'omissions' => []))
  end

  it 'keeps treatment mappings distinct and stores no numerical rate on an outcome' do
    expect(artifact.dig('treatments', 'zero', 'additional_code')).to eq('VATZ')
    expect(artifact.dig('treatments', 'exempt', 'additional_code')).to eq('VATE')
    expect(artifact.dig('treatments', 'reduced', 'additional_code')).to eq('VATR')
    expect(artifact.dig('treatments', 'standard', 'additional_code')).to be_nil

    artifact.fetch('journeys').flat_map { |journey| journey.fetch('outcomes') }.each do |outcome|
      expect(outcome.keys).not_to include('rate', 'percentage', 'vat_rate')
    end
  end

  it 'uses hidden fallthrough at this module boundary and defers exhaustive default to the composer' do
    bases = artifact.fetch('journeys').flat_map { |journey| journey.fetch('outcomes') }.pluck('basis').uniq
    fallthroughs = artifact.fetch('journeys').flat_map { |journey|
      journey.fetch('questions').flat_map { |question| question.fetch('answers').pluck('next') }
    }.select { |transition| transition.fetch('type') == 'fallthrough' }

    expect(bases).to eq(%w[explicit_guidance])
    expect(fallthroughs).not_to be_empty
    expect(fallthroughs).to all(include('trader_visible' => false, 'id' => 'next-applicable-rule'))
    fallthrough_answers = artifact.fetch('journeys').flat_map { |journey| journey.fetch('questions') }
                                  .flat_map { |question| question.fetch('answers') }
                                  .select { |answer| answer.dig('next', 'type') == 'fallthrough' }
    expect(fallthrough_answers).to all(include('relief_disposition' => 'declined'))
  end

  it 'records what the reference-expanded catering packet made possible' do
    comparison = artifact.fetch('catering_packet_comparison')

    expect(comparison.fetch('reference_expanded_question_count')).to be > comparison.fetch('local_question_count')
    expect(comparison.fetch('questions_only_possible_with_references')).to include(
      'Does the item fall within a standard-rated food exception identified by VAT Notice 701/14?',
    )
  end

  it 'records assessment, apportionment, and ambiguous cases instead of inventing treatments' do
    finding_ids = artifact.fetch('spike_findings').pluck('id')
    exclusion_ids = artifact.fetch('journeys').flat_map { |journey| journey.fetch('exclusions') }.pluck('id')

    expect(finding_ids).to include('mixed-and-apportioned-supplies', 'cranberry-snacking-ambiguity')
    expect(exclusion_ids).to include('mixed-travel-system', 'vehicle-with-seat-supply-assessment', 'ambiguous-snacking-description')
  end
end
