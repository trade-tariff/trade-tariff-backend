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
              description: "DAIRY PRODUCE; BIRDS' EGGS; NATURAL HONEY; EDIBLE PRODUCTS OF ANIMAL ORIGIN, NOT ELSEWHERE SPECIFIED OR INCLUDED",
              cnt: 1,
              score: 74.98428,
              avg: 74.98428,
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
