RSpec.describe Api::Beta::ChapterStatisticsSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :single_hit, :generate_heading_and_chapter_statistics).chapter_statistics }

    let(:expected) do
      {
        data: [
          {
            id: '04',
            type: :chapter_statistic,
            attributes: {
              description: "Dairy produce; birds' eggs; natural honey; edible products of animal origin, not elsewhere specified or included",
              cnt: 1,
              score: 79.16452,
              avg: 79.16452,
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
