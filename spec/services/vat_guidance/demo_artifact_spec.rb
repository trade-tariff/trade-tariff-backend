RSpec.describe VatGuidance::DemoArtifact do
  subject(:projection) { described_class.new(path:).call }

  let(:path) { VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance/hmrc_poc.json') }

  it 'projects only the browser-demo contract from the hash-valid artifact', :aggregate_failures do
    expect(projection.keys).to contain_exactly(
      'schema_version',
      'ticket',
      'source_artifact_sha256',
      'service_position',
      'spike_status',
      'summary',
      'composed_commodity_journeys',
      'notice_journeys',
    )
    expect(projection.fetch('composed_commodity_journeys')).to all(include('production_eligible' => false))
    expect(projection.fetch('notice_journeys')).to contain_exactly(
      include(
        'id' => 'notice-701-14-food-exceptions',
        'kind' => 'notice',
        'applicable_commodity_codes' => %w[2005202000 2008939120 2008979890],
        'review_mode' => 'pending_domain_review',
        'production_eligible' => false,
        'evidence_only' => true,
        'resolved_answer_paths' => contain_exactly(
          include('treatment' => 'standard', 'additional_code' => nil, 'measure_ids' => []),
          include('treatment' => 'zero', 'additional_code' => nil, 'measure_ids' => []),
        ),
      ),
      include(
        'id' => 'notice-709-1-catering-reference-expanded',
        'kind' => 'notice',
        'applicable_commodity_codes' => %w[2005202000 2008939120 2008979890],
        'review_mode' => 'pending_domain_review',
        'production_eligible' => false,
        'evidence_only' => true,
        'resolved_answer_paths' => contain_exactly(
          include('treatment' => 'standard', 'additional_code' => nil, 'measure_ids' => []),
          include('treatment' => 'standard', 'additional_code' => nil, 'measure_ids' => []),
          include('treatment' => 'zero', 'additional_code' => nil, 'measure_ids' => []),
        ),
      ),
    )
  end

  it 'rejects a tampered artifact' do
    artifact = JSON.parse(File.read(path))
    artifact.fetch('spike_status')['runtime_approved'] = true
    tampered_path = Pathname.new(Dir::Tmpname.create('vat-guidance-demo') {})
    File.write(tampered_path, JSON.generate(artifact))

    expect { described_class.new(path: tampered_path).call }.to raise_error(
      described_class::InvalidArtifact,
      /hash is invalid/,
    )
  ensure
    FileUtils.rm_f(tampered_path) if tampered_path
  end
end
