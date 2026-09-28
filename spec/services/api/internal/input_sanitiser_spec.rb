RSpec.describe Api::Internal::InputSanitiser do
  subject(:result) { described_class.new(query).call }

  before do
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
  end

  describe '#call' do
    context 'when nil input' do
      let(:query) { nil }

      it 'returns blank query' do
        expect(result).to eq(query: '')
      end
    end

    context 'when input contains HTML tags' do
      let(:query) { '<b>shoes</b>' }

      it 'strips the tags' do
        expect(result).to eq(query: 'shoes')
      end
    end

    context 'when input contains script tags' do
      let(:query) { '<script>alert(1)</script>' }

      it 'strips the tags' do
        expect(result).to eq(query: 'alert(1)')
      end
    end

    context 'when input has excessive whitespace' do
      let(:query) { '  red   shoes  ' }

      it 'normalises whitespace' do
        expect(result).to eq(query: 'red shoes')
      end
    end

    context 'when input is exactly the max length' do
      let(:query) { 'a' * 1000 }

      it 'returns the cleaned query' do
        expect(result).to eq(query: query)
      end
    end

    context 'when input exceeds max length' do
      let(:query) { 'a' * 1001 }

      it 'returns an error' do
        expect(result[:errors]).to be_present
        expect(result[:errors].first[:status]).to eq('422')
        expect(result[:errors].first[:detail]).to eq('Query exceeds maximum length of 1000 characters')
      end
    end

    context 'when max length is configured via AdminConfiguration' do
      let(:query) { 'a' * 11 }

      before do
        create(:admin_configuration, :integer, name: 'input_sanitiser_max_length', value: 10)
      end

      it 'uses the configured max length' do
        expect(result[:errors]).to be_present
        expect(result[:errors].first[:detail]).to include('10 characters')
      end
    end

    context 'when max length is configured above 1000' do
      let(:query) { 'a' * 1001 }

      before do
        create(:admin_configuration, :integer, name: 'input_sanitiser_max_length', value: 1100)
      end

      it 'caps validation at 1000 characters' do
        expect(result[:errors]).to be_present
        expect(result[:errors].first[:detail]).to eq('Query exceeds maximum length of 1000 characters')
      end
    end

    context 'when sanitiser is disabled' do
      let(:query) { '<b>shoes</b>' }

      before do
        allow(AdminConfiguration).to receive(:enabled?).with('input_sanitiser_enabled').and_return(false)
      end

      it 'passes query through unchanged' do
        expect(result).to eq(query: '<b>shoes</b>')
      end
    end
  end
end
