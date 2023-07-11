RSpec.describe BulkSearch::Search do
  subject(:search) do
    described_class.build(
      input_description:,
      number_of_digits:,
      search_results:,
    )
  end

  let(:search_results) do
    [
      {
        short_code: '950720',
        goods_nomenclature_item_id: '9507200000',
        description: 'Fish-hooks, whether or not snelled',
        producline_suffix: '80',
        goods_nomenclature_class: 'Subheading',
        declarable: false,
        reason: 'matching_digit_ancestor',
        score: 32.99,
      },
    ]
  end

  let(:input_description) { 'red herring' }
  let(:number_of_digits) { 8 }

  describe 'validations' do
    context 'when number_of_digits is not 6 or 8' do
      let(:number_of_digits) { 7 }

      it { expect(search).not_to be_valid }
    end

    context 'when number_of_digits is 6' do
      let(:number_of_digits) { 6 }

      it { expect(search).to be_valid }
    end

    context 'when number_of_digits is 8' do
      let(:number_of_digits) { 8 }

      it { expect(search).to be_valid }
    end
  end

  describe '#search_results' do
    it { expect(search.search_results).to all(be_a(BulkSearch::SearchResult)) }
  end

  describe '#no_results!' do
    before { search.no_results! }

    it { expect(search.search_results).to all(be_a(BulkSearch::SearchResult)) }
    it { expect(search.search_results.first.short_code).to eq('99999999') }
    it { expect(search.search_results.first.score).to eq(0) }
  end

  describe '#search_result_ids' do
    it { expect(search.search_result_ids).to be_present }
  end
end
