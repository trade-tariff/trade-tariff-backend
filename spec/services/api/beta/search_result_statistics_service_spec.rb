RSpec.describe Api::Beta::SearchResultStatisticsService do
  describe '#call' do
    subject(:statistics) { described_class.new(hits).call }

    context 'when there are multiple hits' do
      let(:hits) { build(:search_result, :multiple_hits).hits }

      let(:expected_chapter_statistics) do
        {
          '01' => {
            'id' => '01',
            'description' => 'LIVE ANIMALS',
            'score' => 1133.32071,
            'cnt' => 8,
            'avg' => 141.66508875,
          },
          '03' => {
            'id' => '03',
            'description' => 'FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES',
            'score' => 138.529,
            'cnt' => 2,
            'avg' => 69.2645,
          },
        }
      end

      let(:expected_heading_statistics) do
        {
          '0101' => {
            'id' => '0101',
            'description' => 'Live horses, asses, mules and hinnies',
            'chapter_id' => '01',
            'chapter_description' => 'LIVE ANIMALS',
            'score' => 1133.32071,
            'cnt' => 8,
            'avg' => 141.66508875,
            'chapter_score' => 1133.32071,
          },
          '0302' => {
            'id' => '0302',
            'description' => 'Fish, fresh or chilled, excluding fish fillets and other fish meat of heading 0304',
            'chapter_id' => '03',
            'chapter_description' => 'FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES',
            'score' => 138.529,
            'cnt' => 2,
            'avg' => 69.2645,
            'chapter_score' => 138.529,
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
