RSpec.describe TradeTariffBackend::SearchResponse do
  subject(:response) { described_class.new(response_data) }

  let(:hits_array) { [{ '_source' => { 'goods_nomenclature_item_id' => '0101010000' } }] }
  let(:hits_hash) { { 'hits' => hits_array, 'total' => { 'value' => 1 } } }
  let(:response_data) { { 'hits' => hits_hash } }

  describe '#[]' do
    it 'returns the raw value at the given key' do
      expect(response['hits']).to eq hits_hash
    end
  end

  describe '#dig' do
    it 'digs into the underlying hash' do
      expect(response.dig('hits', 'total', 'value')).to eq 1
    end
  end

  describe '#error?' do
    context 'when no error key is present' do
      it { expect(response.error?).to be false }
    end

    context 'when an error key is present' do
      subject(:response) { described_class.new({ 'error' => 'something went wrong' }) }

      it { expect(response.error?).to be true }
    end
  end

  describe '#error' do
    subject(:response) { described_class.new({ 'error' => 'query failed' }) }

    it 'returns the error value' do
      expect(response.error).to eq 'query failed'
    end
  end

  describe '#responses' do
    subject(:response) do
      described_class.new({ 'responses' => [{ 'hits' => hits_hash }, { 'error' => 'bad' }] })
    end

    it 'returns an array of SearchResponse objects' do
      expect(response.responses).to all be_a described_class
    end

    it 'returns one per msearch response' do
      expect(response.responses.size).to eq 2
    end

    context 'when responses key is absent' do
      subject(:response) { described_class.new({}) }

      it { expect(response.responses).to eq [] }
    end
  end

  describe '#hits' do
    context 'when hits is a hash' do
      it 'returns a SearchResponse wrapping the hits hash' do
        expect(response.hits).to be_a described_class
        expect(response.hits['hits']).to eq hits_array
      end
    end

    context 'when hits is an array' do
      subject(:response) { described_class.new({ 'hits' => hits_array }) }

      it 'returns the array directly' do
        expect(response.hits).to eq hits_array
      end
    end

    context 'when hits key is absent' do
      subject(:response) { described_class.new({}) }

      it { expect(response.hits).to be_nil }
    end
  end

  describe '#hits!' do
    it 'returns a SearchResponse wrapping the hits hash' do
      expect(response.hits!).to be_a described_class
    end

    it 'chains to return the inner hits array' do
      expect(response.hits!.hits!).to eq hits_array
    end

    context 'when hits key is absent' do
      subject(:response) { described_class.new({}) }

      it 'raises KeyError' do
        expect { response.hits! }.to raise_error(KeyError, /'hits'/)
      end
    end
  end

  describe 'jsonapi-serializer compatibility' do
    it 'does not respond to :map' do
      expect(response.respond_to?(:map)).to be false
    end
  end
end
