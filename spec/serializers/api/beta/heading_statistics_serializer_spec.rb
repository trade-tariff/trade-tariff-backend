RSpec.describe Api::Beta::HeadingStatisticsSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :single_hit, :generate_statistics).heading_statistics }

    let(:expected) do
      {
        data: [
          {
            id: '0406',
            type: :heading_statistic,
            attributes: {
              description: nil,
              chapter_id: '04',
              chapter_description: nil,
              score: 77.73483,
              cnt: 1,
              avg: 77.73483,
              chapter_score: 77.73483,
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
