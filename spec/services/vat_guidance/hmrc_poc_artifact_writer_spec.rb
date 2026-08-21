RSpec.describe VatGuidance::HmrcPocArtifactWriter do
  let(:artifact) do
    VatGuidance::HmrcPocArtifactBuilder.new(
      poc_artifact('context_graph.json'),
      poc_artifact('context_packets.json'),
      poc_artifact('question_journeys.json'),
    ).call
  end

  it 'writes matching JSON and HTML artifacts' do
    Dir.mktmpdir do |directory|
      json_path = Pathname.new(directory).join('hmrc_poc.json')
      html_path = Pathname.new(directory).join('hmrc_poc.html')

      described_class.new(json_path, html_path, artifact).call

      expect(JSON.parse(File.read(json_path))).to eq(artifact)
      expect(File.read(html_path)).to eq(VatGuidance::HmrcPocRenderer.new(artifact).call)
    end
  end

  it 'renders both payloads before replacing either previous artifact' do
    Dir.mktmpdir do |directory|
      json_path = Pathname.new(directory).join('hmrc_poc.json')
      html_path = Pathname.new(directory).join('hmrc_poc.html')
      File.write(json_path, 'previous json')
      File.write(html_path, 'previous html')
      allow(VatGuidance::HmrcPocRenderer).to receive(:new).and_raise('render failed')

      expect { described_class.new(json_path, html_path, artifact).call }.to raise_error('render failed')
      expect(File.read(json_path)).to eq('previous json')
      expect(File.read(html_path)).to eq('previous html')
    end
  end

  it 'rolls HTML back when publishing the JSON half of the pair fails' do
    Dir.mktmpdir do |directory|
      json_path = Pathname.new(directory).join('json-target-directory')
      html_path = Pathname.new(directory).join('hmrc_poc.html')
      FileUtils.mkdir_p(json_path)
      File.write(html_path, 'previous html')

      expect { described_class.new(json_path, html_path, artifact).call }.to raise_error(SystemCallError)
      expect(File.read(html_path)).to eq('previous html')
      expect(json_path).to be_directory
    end
  end

  it 'refuses to write an artifact whose content changed after hashing' do
    artifact.fetch('summary')['answer_paths'] = -1

    Dir.mktmpdir do |directory|
      expect {
        described_class.new(
          Pathname.new(directory).join('hmrc_poc.json'),
          Pathname.new(directory).join('hmrc_poc.html'),
          artifact,
        ).call
      }.to raise_error(ArgumentError, 'HMRC PoC artifact content hash is invalid')
    end
  end

  def poc_artifact(filename)
    JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance', filename)))
  end
end
