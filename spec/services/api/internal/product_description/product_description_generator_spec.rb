RSpec.describe Api::Internal::ProductDescription::ProductDescriptionGenerator do
  describe '.call' do
    let(:extracted_content) do
      Api::Internal::ProductDescription::ExtractedContent.new(
        title: "Men's cotton T-shirt",
        meta_description: 'A soft short-sleeved T-shirt made from cotton.',
        open_graph_title: nil,
        open_graph_description: nil,
        h1: "Men's cotton T-shirt",
        product_data: { 'brand' => 'Example', 'material' => '100% cotton' },
        body_text: 'This product has short sleeves, a crew neck and a regular fit.',
      )
    end

    it 'returns a generated product description' do
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => "Lightweight men's cotton T-shirt with short sleeves and a crew neck",
          'confidence' => 'high',
          'metadata' => { 'title' => "Men's cotton T-shirt", 'brand' => 'Example' },
        },
      )

      result = described_class.call(extracted_content, source_url: 'https://example.com/product')

      expect(result).to be_success
      expect(result).to have_attributes(
        description: "Lightweight men's cotton T-shirt with short sleeves and a crew neck",
        source_url: 'https://example.com/product',
        confidence: 'high',
        metadata: { 'title' => "Men's cotton T-shirt", 'brand' => 'Example' },
      )
      expect(OpenaiClient).to have_received(:call) do |messages|
        expect(messages).to be_an(Array)
        expect(messages.last[:content]).to include("Men's cotton T-shirt")
        expect(messages.last[:content]).not_to include('<html')
      end
    end

    it 'uses the admin-configured product description model' do
      allow(AdminConfiguration).to receive(:nested_options_value)
        .with('product_description_model')
        .and_return({ selected: 'gpt-4.1-mini-2025-04-14', sub_values: {} })
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => 'Cotton T-shirt',
          'confidence' => 'high',
          'metadata' => {},
        },
      )

      described_class.call(extracted_content, source_url: 'https://example.com/product')

      expect(OpenaiClient).to have_received(:call).with(
        an_instance_of(Array),
        model: 'gpt-4.1-mini-2025-04-14',
        reasoning_effort: nil,
      )
    end

    it 'sanitizes AI output' do
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => "Cotton T-shirt\u0000",
          'confidence' => 'medium',
          'metadata' => { 'title' => "Men's cotton T-shirt\u0000" },
        },
      )

      result = described_class.call(extracted_content, source_url: 'https://example.com/product')

      expect(result.description).to eq('Cotton T-shirt')
      expect(result.metadata).to eq('title' => "Men's cotton T-shirt")
    end

    it 'normalizes unknown confidence to medium' do
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => 'Cotton T-shirt',
          'confidence' => 'certain',
          'metadata' => {},
        },
      )

      result = described_class.call(extracted_content, source_url: 'https://example.com/product')

      expect(result.confidence).to eq('medium')
    end

    it 'rejects blank descriptions' do
      allow(OpenaiClient).to receive(:call).and_return(
        {
          'description' => '',
          'confidence' => 'low',
          'metadata' => {},
        },
      )

      result = described_class.call(extracted_content, source_url: 'https://example.com/product')

      expect(result).not_to be_success
      expect(result.error_title).to eq('Malformed product description')
      expect(result.error_detail).to eq('Generated description was blank')
    end

    it 'rejects malformed responses' do
      allow(OpenaiClient).to receive(:call).and_return('not json')

      result = described_class.call(extracted_content, source_url: 'https://example.com/product')

      expect(result).not_to be_success
      expect(result.error_title).to eq('Malformed product description')
      expect(result.error_detail).to eq('Generated response was not valid')
    end
  end
end
