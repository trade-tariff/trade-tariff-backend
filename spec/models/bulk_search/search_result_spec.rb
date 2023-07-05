require 'rails_helper'

RSpec.describe BulkSearch::SearchResult do
  subject(:search_result) do
    described_class.build(
      number_of_digits: 6,
      short_code: '950720',
      score: 32.91932119,
    )
  end

  describe '#id' do
    it { expect(search_result.id).to eq('950720-32.92') }
  end

  describe '#presented_score' do
    it { expect(search_result.presented_score).to eq(32.92) }
  end
end
