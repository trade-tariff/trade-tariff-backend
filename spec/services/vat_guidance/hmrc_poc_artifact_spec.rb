RSpec.describe 'generated AI-1146 HMRC proof of concept' do
  subject(:artifact) { JSON.parse(File.read(json_path)) }

  let(:json_path) { VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance/hmrc_poc.json') }
  let(:html_path) { VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance/hmrc_poc.html') }
  let(:context_graph) { poc_artifact('context_graph.json') }
  let(:context_packets) { poc_artifact('context_packets.json') }
  let(:question_journeys) { poc_artifact('question_journeys.json') }

  it 'is exactly reproducible from the committed AI-1145 artifact' do
    rebuilt = VatGuidance::HmrcPocArtifactBuilder.new(context_graph, context_packets, question_journeys).call

    expect(artifact).to eq(rebuilt)
    expect(artifact.fetch('content_sha256')).to eq(
      VatGuidance::QuestionJourneyArtifactBuilder.content_sha256(artifact),
    )
  end

  it 'commits HTML generated from exactly the same artifact' do
    expect(File.read(html_path)).to eq(VatGuidance::HmrcPocRenderer.new(artifact).call)
  end

  it 'keeps the entire spike offline and explicitly unapproved for runtime' do
    expect(artifact.dig('spike_status', 'runtime_approved')).to be(false)
    expect(artifact.dig('spike_status', 'production_ready')).to be(false)
    expect(artifact.fetch('answer_paths')).to all(
      satisfy { |path| %w[spike_recorded pending_domain_review].include?(path.dig('review', 'status')) },
    )
  end

  def poc_artifact(filename)
    JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance', filename)))
  end
end
