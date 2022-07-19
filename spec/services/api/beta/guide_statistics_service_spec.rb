RSpec.describe Api::Beta::GuideStatisticsService do
  describe '#call' do
    subject(:call) { described_class.new(goods_nomenclature_hits).call }

    context 'when there are guides returned' do
      let(:goods_nomenclature_hits) { build(:search_result, :clothing).hits }

      let(:expected_guides) do
        {
          18 => {
            'id' => 18,
            'title' => 'Textiles and textile articles',
            'image' => 'textiles.png',
            'url' => 'https://www.gov.uk/guidance/classifying-textile-apparel',
            'strapline' => 'Get help to classify textiles and which headings and codes to use.',
            'percentage' => 100,
            'count' => 10,
          },
        }
      end

      it { is_expected.to eq(expected_guides) }
    end

    context 'when there are no guides' do
      let(:goods_nomenclature_hits) { build(:search_result, :no_guides).hits }

      let(:expected_guides) { {} }

      it { is_expected.to eq(expected_guides) }
    end

    context 'when there are no search results' do
      let(:goods_nomenclature_hits) { build(:search_result, :no_hits).hits }

      let(:expected_guides) { {} }

      it { is_expected.to eq(expected_guides) }
    end
  end
end
