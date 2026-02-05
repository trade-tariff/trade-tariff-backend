RSpec.describe ExtractBottomJson do
  describe '.call' do
    subject(:result) { described_class.call(text) }

    context 'when AI returns clean JSON (most common case)' do
      let(:text) { '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}' }

      it 'parses directly' do
        expect(result).to eq({
          'answers' => [{ 'commodity_code' => '4202210000', 'confidence' => 'Strong' }],
        })
      end
    end

    context 'when AI returns JSON with preamble explanation' do
      let(:text) do
        <<~TEXT
          Based on the search results and the trader's response about leather material,
          I can now provide a confident classification.

          {"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}
        TEXT
      end

      it 'extracts the JSON from the end' do
        expect(result).to eq({
          'answers' => [{ 'commodity_code' => '4202210000', 'confidence' => 'Strong' }],
        })
      end
    end

    context 'when AI wraps JSON in markdown code fences' do
      let(:text) do
        <<~TEXT
          ```json
          {"questions": [{"question": "What is the material?", "options": ["Leather", "Synthetic"]}]}
          ```
        TEXT
      end

      it 'extracts the JSON from within the fences' do
        expect(result).to eq({
          'questions' => [{ 'question' => 'What is the material?', 'options' => %w[Leather Synthetic] }],
        })
      end
    end

    context 'when AI returns questions response' do
      let(:text) do
        '{"questions": [{"question": "Is this for commercial use?", "options": ["Yes", "No"]}]}'
      end

      it 'parses questions format' do
        expect(result).to eq({
          'questions' => [{ 'question' => 'Is this for commercial use?', 'options' => %w[Yes No] }],
        })
      end
    end

    context 'when AI returns error response' do
      let(:text) { '{"error": "Contradictory answers given"}' }

      it 'parses error format' do
        expect(result).to eq({ 'error' => 'Contradictory answers given' })
      end
    end

    context 'when AI returns a JSON array' do
      let(:text) { '[{"code": "123"}, {"code": "456"}]' }

      it 'parses arrays' do
        expect(result).to eq([{ 'code' => '123' }, { 'code' => '456' }])
      end
    end

    context 'when input is already a Hash (pre-parsed JSON)' do
      let(:text) { { 'answers' => [{ 'commodity_code' => '123' }] } }

      it 'returns the hash as-is' do
        expect(result).to eq({ 'answers' => [{ 'commodity_code' => '123' }] })
      end
    end

    context 'when input is already an Array (pre-parsed JSON)' do
      let(:text) { [{ 'code' => '123' }, { 'code' => '456' }] }

      it 'returns the array as-is' do
        expect(result).to eq([{ 'code' => '123' }, { 'code' => '456' }])
      end
    end

    context 'when text is blank' do
      let(:text) { '' }

      it { is_expected.to eq({}) }
    end

    context 'when text is nil' do
      let(:text) { nil }

      it { is_expected.to eq({}) }
    end

    context 'when AI returns no JSON at all' do
      let(:text) { 'I apologize, but I cannot help with that request.' }

      it { is_expected.to eq({}) }
    end

    context 'when AI returns malformed JSON' do
      let(:text) { '{"key": "value"' }

      it { is_expected.to eq({}) }
    end
  end
end
