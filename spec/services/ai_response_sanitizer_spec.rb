RSpec.describe AiResponseSanitizer do
  describe '.call' do
    it 'removes null bytes from strings' do
      response = { 'description' => "polyethylene scrap with density \u0000 test" }

      result = described_class.call(response)

      expect(result['description']).to eq('polyethylene scrap with density  test')
      expect(result['description']).not_to include("\u0000")
    end

    it 'handles multiple null bytes' do
      response = { 'text' => "\u0000start\u0000middle\u0000end\u0000" }

      result = described_class.call(response)

      expect(result['text']).to eq('startmiddleend')
    end

    it 'removes invalid byte order marks' do
      response = { 'text' => "test\uFFFEvalue" }

      result = described_class.call(response)

      expect(result['text']).to eq('testvalue')
    end

    it 'removes non-character markers' do
      response = { 'text' => "test\uFFFFvalue" }

      result = described_class.call(response)

      expect(result['text']).to eq('testvalue')
    end

    it 'recursively sanitizes nested hashes' do
      response = {
        'data' => {
          'nested' => {
            'description' => "contains \u0000 null",
          },
        },
      }

      result = described_class.call(response)

      expect(result['data']['nested']['description']).to eq('contains  null')
    end

    it 'recursively sanitizes arrays' do
      response = {
        'data' => [
          { 'text' => "first \u0000 item" },
          { 'text' => "second \u0000 item" },
        ],
      }

      result = described_class.call(response)

      expect(result['data'][0]['text']).to eq('first  item')
      expect(result['data'][1]['text']).to eq('second  item')
    end

    it 'handles arrays of strings' do
      response = {
        'synonyms' => ["term\u0000one", "term\u0000two"],
      }

      result = described_class.call(response)

      expect(result['synonyms']).to eq(%w[termone termtwo])
    end

    it 'preserves non-string values' do
      response = {
        'count' => 42,
        'active' => true,
        'ratio' => 3.14,
        'nothing' => nil,
      }

      result = described_class.call(response)

      expect(result['count']).to eq(42)
      expect(result['active']).to be(true)
      expect(result['ratio']).to eq(3.14)
      expect(result['nothing']).to be_nil
    end

    it 'handles empty strings' do
      response = { 'text' => '' }

      result = described_class.call(response)

      expect(result['text']).to eq('')
    end

    it 'handles empty hashes' do
      result = described_class.call({})

      expect(result).to eq({})
    end

    it 'handles empty arrays' do
      response = { 'data' => [] }

      result = described_class.call(response)

      expect(result['data']).to eq([])
    end

    it 'preserves valid Unicode characters' do
      response = { 'text' => 'Café résumé naïve 日本語 emoji 🎉' }

      result = described_class.call(response)

      expect(result['text']).to eq('Café résumé naïve 日本語 emoji 🎉')
    end

    it 'handles strings with mixed valid and invalid characters' do
      response = { 'text' => "Valid text \u0000 more valid café \u0000 end" }

      result = described_class.call(response)

      expect(result['text']).to eq('Valid text  more valid café  end')
    end

    context 'with realistic AI response structure' do
      let(:response) do
        {
          'data' => [
            {
              'commodity_code' => '3915102000',
              'description' => "Polyethylene scrap with density \u0000 suitable for recycling",
              'known_brands' => [],
              'colloquial_terms' => ["plastic waste\u0000", 'PE scrap'],
              'synonyms' => ['polymer scrap', "recycled plastic\u0000material"],
              'original_description' => 'Waste, parings and scrap',
            },
          ],
        }
      end

      it 'sanitizes all fields correctly' do
        result = described_class.call(response)
        item = result['data'].first

        expect(item['description']).to eq('Polyethylene scrap with density  suitable for recycling')
        expect(item['colloquial_terms']).to eq(['plastic waste', 'PE scrap'])
        expect(item['synonyms']).to eq(['polymer scrap', 'recycled plasticmaterial'])
        expect(item['commodity_code']).to eq('3915102000')
        expect(item['original_description']).to eq('Waste, parings and scrap')
      end

      it 'produces PostgreSQL-safe output' do
        result = described_class.call(response)
        json_string = result.to_json

        expect(json_string).not_to include('\u0000')
        expect(json_string).not_to include("\u0000")
      end
    end
  end

  describe '#call' do
    it 'works as instance method' do
      sanitizer = described_class.new('text' => "test\u0000value")

      result = sanitizer.call

      expect(result['text']).to eq('testvalue')
    end
  end
end
