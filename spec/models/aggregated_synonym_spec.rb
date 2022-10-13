RSpec.describe AggregatedSynonym do
  describe '.exists?' do
    subject(:exists?) { described_class.exists?(search_query) }

    context 'when the aggregated synonym exists' do
      let(:search_query) { 'blacKbird' }

      it { is_expected.to be(true) }
    end

    context 'when the aggregated synonym does not exist' do
      let(:search_query) { 'brownbird' }

      it { is_expected.to be(false) }
    end

    context 'when the search query is nil' do
      let(:search_query) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the search query is empty' do
      let(:search_query) { '' }

      it { is_expected.to be(false) }
    end
  end

  describe '.aggregated_synonyms' do
    subject(:aggregated_synonyms) { described_class.aggregated_synonyms }

    it { is_expected.to be_a(Set) }

    it 'correctly loads the explicit and equivalent synonyms' do
      expect(aggregated_synonyms).to match_array(
        [
          '0106390000',
          'blackbird',
          'bluebird',
          'jay',
          'magpie',
          'robin',
          'sparrow',
          'yakutian laika',
        ],
      )
    end
  end
end
