RSpec.describe VatGuidance::QuestionJourneyArtifactBuilder do
  subject(:build_artifact) { described_class.new(packets, candidates).call }

  let(:packets) do
    JSON.parse(Rails.root.join('data/vat_guidance/context_packets.json').read)
  end
  let(:candidates) do
    JSON.parse(Rails.root.join('data/vat_guidance/question_journey_candidates.json').read)
  end

  it 'reports a missing journey source packet as a controlled build error' do
    candidates.fetch('journeys').first.delete('source_packet_id')

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      'journey source_packet_id values must be present strings',
    )
  end

  it 'reports missing review-record fields as controlled build errors' do
    record = candidates.fetch('packet_review_records').first
    record.delete('status')

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      'packet review record has missing fields: status',
    )
  end

  it 'reports a malformed review-record source hash as a controlled build error' do
    candidates.fetch('packet_review_records').first.delete('source_packet_sha256')

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      'packet review record has missing fields: source_packet_sha256',
    )
  end

  it 'rejects an unreviewed generation failure from the reviewed artifact' do
    attempt = candidates.fetch('packet_review_records').first
    attempt['method'] = 'llm_generation'
    attempt['status'] = 'generation_failed'

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      /has invalid status/,
    )
  end

  it 'accepts a model-generated journey only with evidence bound to the stored journey' do
    journey = candidates.fetch('journeys').first
    attempt = attempt_for(journey)
    attempt['method'] = 'llm_generation'
    attempt['status'] = 'journey_generated'
    attempt['model_response_sha256'] = Digest::SHA256.hexdigest(described_class.canonical_json(journey))

    artifact = build_artifact

    expect(artifact.fetch('packet_review_records').find { |item| item == attempt }).to eq(attempt)
  end

  it 'rejects model evidence that is not bound to the stored journey' do
    journey = candidates.fetch('journeys').first
    attempt = attempt_for(journey)
    attempt['method'] = 'llm_generation'
    attempt['status'] = 'journey_generated'
    attempt['model_response_sha256'] = '0' * 64

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      /model response hash has drifted/,
    )
  end

  it 'forbids model-response evidence on a human-review disposition' do
    journey = candidates.fetch('journeys').first
    attempt = attempt_for(journey)
    attempt['model_response_sha256'] = Digest::SHA256.hexdigest(described_class.canonical_json(journey))

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      /manual review cannot have a model response hash/,
    )
  end

  it 'does not allow manual review records to masquerade as raw generation attempts' do
    candidates['packet_generation_attempts'] = candidates.delete('packet_review_records')

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      /packet_generation_attempts may contain only llm_generation records/,
    )
  end

  it 'rejects ambiguous reviewed and generated record envelopes' do
    candidates['packet_generation_attempts'] = candidates.fetch('packet_review_records').deep_dup

    expect { build_artifact }.to raise_error(
      described_class::BuildError,
      /must provide packet_review_records or packet_generation_attempts, not both/,
    )
  end

  def attempt_for(journey)
    candidates.fetch('packet_review_records').find do |attempt|
      attempt.fetch('packet_id') == journey.fetch('source_packet_id')
    end
  end
end
