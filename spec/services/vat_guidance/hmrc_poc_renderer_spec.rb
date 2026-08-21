RSpec.describe VatGuidance::HmrcPocRenderer do
  subject(:html) { described_class.new(artifact).call }

  let(:artifact) do
    VatGuidance::HmrcPocArtifactBuilder.new(
      poc_artifact('context_graph.json'),
      poc_artifact('context_packets.json'),
      poc_artifact('question_journeys.json'),
    ).call
  end

  it 'renders a self-contained browsable PoC with the mandatory non-liability framing' do
    expect(html).to include('<!doctype html>', 'VAT guidance journey proof of concept')
    expect(html).to include('Spike only — not approved tax logic.')
    expect(html).to include('does not determine VAT liability')
    expect(html.scan('<details>').size).to eq(228)
    expect(html).to include('Commodity exhaustion notes', '6506101000')
    expect(html).to include('Evidence lineage', '1976 sections', '141 notice packets', '11 journeys')
    expect(html).to include('All-section packet accounting', 'No contract-safe standalone tree')
    expect(html).to include('Pinned measure connection proposals', 'Synthetic end-to-end composition simulation')
    expect(html).to include('spike_simulation_complete', 'Not a domain approval.', 'Walkable composed routes')
    expect(html).to include('Rule paths:')
  end

  it 'escapes untrusted artifact text and does not create unsafe source links' do
    artifact.fetch('answer_paths').first.fetch('steps').first['question'] = '<script>alert("x")</script>'
    artifact.fetch('answer_paths').first.fetch('steps').first.fetch('evidence')['node_id'] = 'javascript:alert(1)'

    expect(html).to include('&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;')
    expect(html).not_to include('<script>alert', 'href="javascript:')
  end

  it 'only links evidence nodes that map to a GOV.UK guidance URL' do
    expect(html).to match(%r{href="https://www\.gov\.uk/guidance/[a-z0-9-]+#[a-z0-9-]+"})
  end

  def poc_artifact(filename)
    JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance', filename)))
  end
end
