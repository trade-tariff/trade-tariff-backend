RSpec.describe SearchService::RogueSearchService do
  describe '.call' do
    subject(:call_class) { described_class.call(query_string) }

    context 'when given a recognised erroneous search term' do
      let(:query_string) { 'gift' }

      it 'will return true' do
        expect(call_class).to eq(true)
      end
    end

    context 'when given a recognised erroneous search term with capitals' do
      let(:query_string) { 'Gift' }

      it 'will return true' do
        expect(call_class).to eq(true)
      end
    end

    context 'when given a random search term' do
      let(:query_string) { 'random' }

      it 'will return true' do
        expect(call_class).to eq(false)
      end
    end
  end
end
