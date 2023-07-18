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
              chapter_description: "Dairy produce; birds' eggs; natural honey; edible products of animal origin, not elsewhere specified or included",
              score: 79.16452,
              cnt: 1,
              avg: 79.16452,
              chapter_score: 79.16452,
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
