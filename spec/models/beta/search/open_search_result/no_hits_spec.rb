RSpec.describe Beta::Search::OpenSearchResult::NoHits do
  describe '.build' do
    subject(:result) { described_class.build(nil, search_query_parser_result, goods_nomenclature_query) }

    let(:search_query_parser_result) { build(:search_query_parser_result, :multiple_hits) }
    let(:goods_nomenclature_query) { build(:goods_nomenclature_query, :full_query) }

    it { is_expected.to be_a(Beta::Search::OpenSearchResult) }
    it { expect(result.took).to eq(0) }
    it { expect(result.timed_out).to eq(false) }
    it { expect(result.max_score).to eq(0) }
    it { expect(result.hits.count).to eq(0) }
    it { expect(result.search_query_parser_result).to eq(search_query_parser_result) }
    it { expect(result.goods_nomenclature_query).to eq(goods_nomenclature_query) }
    it { expect(result.id).to eq('') }
    it { expect(result.empty_query).to be(false) }
  end
end
