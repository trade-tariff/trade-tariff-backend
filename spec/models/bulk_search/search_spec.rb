require 'rails_helper'

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

  describe '#search_results' do
    it { expect(search.search_results).to all(be_a(BulkSearch::SearchResult)) }
  end

  describe '#search_result_ids' do
    it { expect(search.search_result_ids).to be_present }
  end
end
