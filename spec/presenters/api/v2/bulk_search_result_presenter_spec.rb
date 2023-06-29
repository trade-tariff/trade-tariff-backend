RSpec.describe Api::V2::BulkSearchResultPresenter do
  describe '.wrap' do
    subject(:result) { described_class.wrap(result_collection) }

    let(:result_collection) { BulkSearch::ResultCollection.build([attributes_for(:bulk_search)]) }

    it { is_expected.to all(be_a(described_class)) }
  end

  describe '#input_description' do
    subject(:input_description) { described_class.new(search, search_result).input_description }

    let(:search) { build(:bulk_search) }
    let(:search_result) { search.search_result_ancestors.first }

    it { is_expected.to eq(search.input_description) }
  end
end
