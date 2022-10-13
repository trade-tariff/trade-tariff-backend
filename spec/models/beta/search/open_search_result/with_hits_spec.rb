RSpec.describe Beta::Search::OpenSearchResult::WithHits do
  describe '.build' do
    subject(:result) { described_class.build(search_result, search_query_parser_result, goods_nomenclature_query) }

    let(:search_result) do
      fixture = file_fixture('beta/search/goods_nomenclatures/multiple_hits.json')

      Hashie::TariffMash.new(JSON.parse(fixture.read))
    end

    let(:search_query_parser_result) { build(:search_query_parser_result, :multiple_hits) }
    let(:goods_nomenclature_query) { build(:goods_nomenclature_query, :full_query) }

    it { is_expected.to be_a(Beta::Search::OpenSearchResult) }
    it { expect(result).to respond_to(:took) }
    it { expect(result.timed_out).to eq(false) }
    it { expect(result).to respond_to(:max_score) }
    it { expect(result.hits.count).to eq(10) }
    it { expect(result.search_query_parser_result).to eq(search_query_parser_result) }
    it { expect(result.goods_nomenclature_query).to eq(goods_nomenclature_query) }
    it { expect(result.id).to eq('773f19eb133e44c7b88f87902b3e557a') }
    it { expect(result.empty_query).to be(false) }
  end
end
