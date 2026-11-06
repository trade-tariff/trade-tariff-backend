RSpec.describe ImageDescriptions::Describe do
  let(:path) { Rails.root.join('tmp/image-description-unit.jpg') }
  let(:result) { { 'description' => 'A red apple.', 'uncertainties' => [] } }

  before do
    allow(File).to receive(:binread).with(path).and_return('normalised-image')
    allow(OpenaiClient).to receive(:call).and_return(result)
  end

  it 'sends normalised bytes with a deadline' do
    expect(described_class.call(path, request_id: 'image-journey')).to eq(result)
    expect(OpenaiClient).to have_received(:call).with(
      [hash_including(role: 'system'), hash_including(role: 'user', content: include(hash_including(type: 'input_image', image_url: 'data:image/jpeg;base64,bm9ybWFsaXNlZC1pbWFnZQ==')))],
      model: 'gpt-4.1-mini', timeout: 20, event_kind: 'image_description',
    )
  end

  ['', '<script>bad</script>', 'x' * 601].each do |description|
    context "with an unusable description of length #{description.length}" do
      let(:result) { { 'description' => description, 'uncertainties' => [] } }

      it 'rejects the model output' do
        expect { described_class.call(path, request_id: 'image-journey') }.to raise_error(described_class::InvalidResponse)
      end
    end
  end

  context 'with malformed uncertainty' do
    let(:result) { { 'description' => 'Apple', 'uncertainties' => 'probably' } }

    it 'rejects the model output' do
      expect { described_class.call(path, request_id: 'image-journey') }.to raise_error(described_class::InvalidResponse)
    end
  end
end
