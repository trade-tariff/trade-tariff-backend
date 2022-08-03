RSpec.describe Api::Beta::HeadingStatisticsSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :single_hit, :generate_heading_and_chapter_statistics).heading_statistics }

    let(:expected) do
      {
        data: [
          {
            id: '0406',
            type: :heading_statistic,
            attributes: {
              description: 'Cheese and curd',
              chapter_id: '04',
              chapter_description: "DAIRY PRODUCE; BIRDS' EGGS; NATURAL HONEY; EDIBLE PRODUCTS OF ANIMAL ORIGIN, NOT ELSEWHERE SPECIFIED OR INCLUDED",
              score: 74.98428,
              cnt: 1,
              avg: 74.98428,
              chapter_score: 74.98428,
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
