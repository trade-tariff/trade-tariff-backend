RSpec.describe Api::Internal::ProductDescription::UrlContentExtractor do
  describe '.call' do
    it 'extracts product-like words from the URL host and path' do
      result = described_class.call('https://www.marksandspencer.com/pure-cotton-garment-dyed-t-shirt/p/clp60770886')

      expect(result).to be_sufficient
      expect(result.title).to eq('marksandspencer pure cotton garment dyed t shirt')
      expect(result.body_text).to eq('URL path suggests: marksandspencer pure cotton garment dyed t shirt')
      expect(result.product_data).to eq('source' => 'url')
    end

    it 'does not include credentials, query strings, fragments, ids, or token-like path segments' do
      result = described_class.call(
        'https://user:secret@example.com/products/cotton-shirt/550e8400-e29b-41d4-a716-446655440000/abc123def456ghi789jkl012mno345?token=secret-token&email=buyer@example.com#private',
      )
      payload = result.to_prompt_payload.to_json

      expect(payload).to include('example cotton shirt')
      expect(payload).not_to include('user')
      expect(payload).not_to include('secret')
      expect(payload).not_to include('token')
      expect(payload).not_to include('buyer')
      expect(payload).not_to include('550e8400')
      expect(payload).not_to include('abc123def456')
      expect(payload).not_to include('private')
    end

    it 'keeps hyphenated product slugs that include product ids' do
      result = described_class.call('https://www.boots.com/remington-hydraluxe-hairdryer-10282703')

      expect(result.title).to eq('boots remington hydraluxe hairdryer')
    end

    it 'does not treat host and route words as sufficient product information' do
      result = described_class.call('https://www.tesco.com/shop/en-GB/products/326236899')

      expect(result).not_to be_sufficient
      expect(result.title).to be_nil
      expect(result.body_text).to be_nil
      expect(result.product_data).to eq({})
    end
  end
end
