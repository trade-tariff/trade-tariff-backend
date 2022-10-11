RSpec.describe Api::Beta::SearchSynonymMatcherService do
  describe '#call' do
    subject(:call) { described_class.new(original_search_query).call }

    context 'when the search query matches an explicit synonym' do
      let(:original_search_query) { 'yakutian laika' }

      it { is_expected.to be(true) }
    end

    context 'when the search query matches an equivalent synonym' do
      let(:original_search_query) { 'sparrow' }

      it { is_expected.to be(true) }
    end

    context 'when the search query does not match a synonym' do
      let(:original_search_query) { 'clothing sets' }

      it { is_expected.to be(false) }
    end
  end
end
