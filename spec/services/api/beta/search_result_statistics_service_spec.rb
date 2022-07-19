RSpec.describe Api::Beta::SearchResultStatisticsService do
  describe '#call' do
    subject(:statistics) { described_class.new(hits).call }

    context 'when there are multiple hits' do
      let(:hits) { build(:search_result, :multiple_hits).hits }
      let(:expected_heading_statistics) do
        {
          '0101' => {
            'id' => '0101',
            'description' => nil,
            'chapter_id' => '01',
            'chapter_description' => nil,
            'score' => 486.00095999999996,
            'cnt' => 7,
            'avg' => 69.42870857142857,
            'chapter_score' => 486.00095999999996,
          },
          '0206' => {
            'id' => '0206',
            'description' => nil,
            'chapter_id' => '02',
            'chapter_description' => nil,
            'score' => 126.879548,
            'cnt' => 2,
            'avg' => 63.439774,
            'chapter_score' => 126.879548,
          },
          '0302' => {
            'id' => '0302',
            'description' => nil,
            'chapter_id' => '03',
            'chapter_description' => nil,
            'score' => 54.07968,
            'cnt' => 1,
            'avg' => 54.07968,
            'chapter_score' => 54.07968,
          },
        }
      end

      let(:expected_chapter_statistics) do
        {
          '01' => {
            'id' => '01',
            'description' => nil,
            'score' => 486.00095999999996,
            'cnt' => 7,
            'avg' => 69.42870857142857,
          },
          '02' => {
            'id' => '02',
            'description' => nil,
            'score' => 126.879548,
            'cnt' => 2,
            'avg' => 63.439774,
          },
          '03' => {
            'id' => '03',
            'description' => nil,
            'score' => 54.07968,
            'cnt' => 1,
            'avg' => 54.07968,
          },
        }
      end

      it { expect(statistics[0]).to eq(expected_chapter_statistics) }
      it { expect(statistics[1]).to eq(expected_heading_statistics) }
    end

    context 'when there are no hits' do
      let(:hits) { build(:search_result, :no_hits).hits }

      it { is_expected.to eq([{}, {}]) }
    end
  end
end
