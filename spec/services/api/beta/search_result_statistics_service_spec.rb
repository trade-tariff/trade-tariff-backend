RSpec.describe Api::Beta::SearchResultStatisticsService do
  describe '#call' do
    subject(:statistics) { described_class.new(hits).call }

    context 'when there are multiple hits' do
      let(:hits) { build(:search_result, :multiple_hits).hits }

      let(:expected_heading_statistics) do
        {
          '0101' => {
            'id' => '0101',
            'description' => 'Live horses, asses, mules and hinnies',
            'chapter_id' => '01',
            'chapter_description' => 'Live animals',
            'score' => 485.68718800000005,
            'cnt' => 7,
            'avg' => 69.38388400000001,
            'chapter_score' => 485.68718800000005,
          },
          '0206' => {
            'id' => '0206',
            'description' => 'Edible offal of bovine animals, swine, sheep, goats, horses, asses, mules or hinnies, fresh, chilled or frozen',
            'chapter_id' => '02',
            'chapter_description' => 'Meat and edible meat offal',
            'score' => 126.686088,
            'cnt' => 2,
            'avg' => 63.343044,
            'chapter_score' => 126.686088,
          },
          '0302' => {
            'id' => '0302',
            'description' => 'Fish, fresh or chilled',
            'chapter_id' => '03',
            'chapter_description' => 'Fish and crustaceans, molluscs and other aquatic invertebrates',
            'score' => 53.984024,
            'cnt' => 1,
            'avg' => 53.984024,
            'chapter_score' => 53.984024,
          },
        }
      end

      let(:expected_chapter_statistics) do
        {
          '01' => {
            'id' => '01',
            'description' => 'Live animals',
            'score' => 485.68718800000005,
            'cnt' => 7,
            'avg' => 69.38388400000001,
          },
          '02' => {
            'id' => '02',
            'description' => 'Meat and edible meat offal',
            'score' => 126.686088,
            'cnt' => 2,
            'avg' => 63.343044,
          },
          '03' => {
            'id' => '03',
            'description' => 'Fish and crustaceans, molluscs and other aquatic invertebrates',
            'score' => 53.984024,
            'cnt' => 1,
            'avg' => 53.984024,
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
