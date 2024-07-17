RSpec.describe SearchService::RogueSearchService do
  describe '.call' do
    subject(:call_class) { described_class.call(query_string) }

    context 'when given a recognised erroneous search term' do
      let(:query_string) { 'gift' }

      it 'returns true' do
        expect(call_class).to be(true)
      end
    end

    context 'when given a recognised erroneous search term with capitals' do
      let(:query_string) { 'Gift' }

      it 'returns true' do
        expect(call_class).to be(true)
      end
    end

    context 'when given a random search term' do
      let(:query_string) { 'random' }

      it 'returns true' do
        expect(call_class).to be(false)
      end
    end
  end
end
