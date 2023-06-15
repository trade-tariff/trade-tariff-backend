require 'rails_helper'

RSpec.describe BulkSearch::Search do
  subject(:search) do
    described_class.build(
      input_description:,
      ancestor_digits:,
      search_result_ancestors:,
    )
  end

  let(:search_result_ancestors) do
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
  let(:ancestor_digits) { 8 }

  describe '#search_result_ancestors' do
    it { expect(search.search_result_ancestors).to all(be_a(BulkSearch::SearchAncestor)) }
  end

  describe '#search_result_ancestor_ids' do
    it { expect(search.search_result_ancestor_ids).to be_present }
  end
end
