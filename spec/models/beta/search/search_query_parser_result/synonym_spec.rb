RSpec.describe Beta::Search::SearchQueryParserResult::Synonym do
  describe '.build' do
    subject(:result) { described_class.build(attributes) }

    let(:attributes) do
      {
        'original_search_query' => 'ash trees',
      }
    end

    it { is_expected.to be_a(Beta::Search::SearchQueryParserResult) }
    it { expect(result.adjectives).to eq([]) }
    it { expect(result.nouns).to eq([]) }
    it { expect(result.noun_chunks).to eq(['ash trees']) }
    it { expect(result.verbs).to eq([]) }
    it { expect(result.original_search_query).to eq('ash trees') }
    it { expect(result.corrected_search_query).to eq('') }
    it { expect(result.id).to eq('7f3be5b089254dac52a8c4e41b0ffa9e') }
  end
end
