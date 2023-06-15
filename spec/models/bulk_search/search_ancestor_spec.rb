require 'rails_helper'

RSpec.describe BulkSearch::SearchAncestor do
  subject(:search_ancestor) do
    described_class.build(
      short_code: '950720',
      goods_nomenclature_item_id: '9507200000',
      description: 'Fish-hooks, whether or not snelled',
      producline_suffix: '80',
      goods_nomenclature_class: 'Subheading',
      declarable: false,
      reason: 'matching_digit_ancestor',
      score: 32.91932119,
    )
  end

  describe '#id' do
    it { expect(search_ancestor.id).to eq('950720-80-32.92') }
  end

  describe '#presented_score' do
    it { expect(search_ancestor.presented_score).to eq(32.92) }
  end
end
