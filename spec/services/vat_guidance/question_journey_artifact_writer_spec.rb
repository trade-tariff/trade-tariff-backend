RSpec.describe VatGuidance::QuestionJourneyArtifactWriter do
  let(:artifact) do
    value = {
      'validation_reports' => [{ 'journey_id' => 'journey-1', 'valid' => true, 'errors' => [] }],
      'payload' => 'valid',
    }
    value['content_sha256'] = VatGuidance::QuestionJourneyArtifactBuilder.content_sha256(value)
    value
  end

  it 'atomically writes a validated, hashed artifact' do
    Dir.mktmpdir do |directory|
      path = Pathname.new(directory).join('artifact.json')

      described_class.new(path, artifact).call

      expect(JSON.parse(File.read(path))).to eq(artifact)
    end
  end

  it 'preserves the previous artifact when validation fails' do
    Dir.mktmpdir do |directory|
      path = Pathname.new(directory).join('artifact.json')
      File.write(path, "previous\n")
      artifact.fetch('validation_reports').first['valid'] = false
      artifact.fetch('validation_reports').first['errors'] = ['bad journey']

      expect { described_class.new(path, artifact).call }.to raise_error(
        VatGuidance::QuestionJourneyArtifactWriter::InvalidArtifact,
        /bad journey/,
      )
      expect(File.read(path)).to eq("previous\n")
    end
  end
end
