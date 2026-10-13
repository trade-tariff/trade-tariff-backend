RSpec.describe InternalSearchQueryNormaliserService do
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:ready) do
    Search::ExpansionVocabulary::Lookup.new(status: :ready, words: Set.new(%w[poultry meat]), generation: 'test')
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(true)
    allow(Search::ExpansionVocabulary).to receive(:lookup).and_return(ready)
    allow(OpenaiClient).to receive(:call).and_return(
      'added_terms' => ['poultry meat', 'zaptoxidinyl serum'], 'reason' => 'trade terms',
    )
  end

  describe '.call' do
    it 'keeps phrase boundaries across the cache', :aggregate_failures do
      fresh = described_class.call(query: 'chicken')
      cached = described_class.call(query: 'chicken')

      expect(fresh.expanded_query).to eq('chicken poultry meat')
      expect(fresh.added_terms).to eq(['poultry meat'])
      expect(cached).to eq(fresh)
      expect(OpenaiClient).to have_received(:call).once
    end

    it 'filters cached proposals against the current vocabulary' do
      described_class.call(query: 'chicken')
      allow(Search::ExpansionVocabulary).to receive(:lookup).and_return(
        Search::ExpansionVocabulary::Lookup.new(status: :unavailable, words: Set.new, generation: nil),
      )
      result = described_class.call(query: 'chicken')

      expect(result.expanded_query).to eq('chicken')
      expect(result.added_terms).to eq([])
      expect(OpenaiClient).to have_received(:call).once
      expect(TradeTariffRequest.search_failures).to be_blank
    end

    it 'keeps a legacy rewrite as one proposal' do
      allow(OpenaiClient).to receive(:call).and_return('expanded_query' => 'poultry meat, zaptoxidinyl serum')

      expect(described_class.call(query: 'chicken').expanded_query).to eq('chicken')
    end

    it 'skips optional work when disabled' do
      allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(false)
      result = described_class.call(query: 'chicken')

      expect(result.added_terms).to eq([])
      expect(result.expanded_query).to eq('chicken')
      expect(OpenaiClient).not_to have_received(:call)
      expect(Search::ExpansionVocabulary).not_to have_received(:lookup)
    end
  end
end
