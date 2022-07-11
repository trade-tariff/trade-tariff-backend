require 'rails_helper'

RSpec.describe Beta::Search::SearchQueryParserResult do
  describe '.build' do
    subject(:result) { described_class.build(attributes) }

    let(:attributes) do
      {
        'tokens' => {
          'adjectives' => %w[tall],
          'nouns' => %w[man],
          'noun_chunks' => ['tall man'],
          'verbs' => [],
        },
        'original_search_query' => 'tall man',
        'corrected_search_query' => 'tall man',
      }
    end

    it { is_expected.to be_a(described_class) }
    it { expect(result.adjectives).to eq(%w[tall]) }
    it { expect(result.nouns).to eq(%w[man]) }
    it { expect(result.noun_chunks).to eq(['tall man']) }
    it { expect(result.verbs).to eq([]) }
    it { expect(result.original_search_query).to eq('tall man') }
    it { expect(result.corrected_search_query).to eq('tall man') }
  end

  describe '#id' do
    subject(:id) { build(:search_query_parser_result).id }

    it { is_expected.to eq('240ad90c8bd0e29cc402ff257d033747') }
  end
end
