RSpec.describe Api::Beta::ChapterStatisticsSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :single_hit, :generate_statistics).chapter_statistics }

    let(:expected) do
      {
        data: [
          {
            attributes: { avg: 77.73483, cnt: 1, description: nil, score: 77.73483 },
            id: '04',
            type: :chapter_statistic,
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
