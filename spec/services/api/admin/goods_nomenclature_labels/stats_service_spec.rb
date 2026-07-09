RSpec.describe Api::Admin::GoodsNomenclatureLabels::StatsService do
  subject(:service) { described_class.new }

  let(:result_class) { described_class::Result }

  describe '#call' do
    let(:result) { service.call }

    context 'when there are no labels' do
      it 'returns zero counts' do
        expect(result).to eq(
          result_class.new(
            total_goods_nomenclatures: 0,
            descriptions_count: 0,
            known_brands_count: 0,
            colloquial_terms_count: 0,
            synonyms_count: 0,
            ai_created_only: 0,
            human_edited: 0,
            coverage_by_chapter: [],
          ),
        )
      end
    end

    context 'when there are labels with various attributes' do
      let(:first_commodity) { create :commodity }
      let(:second_commodity) { create :commodity }
      let(:third_commodity) { create :commodity }

      before do
        create :goods_nomenclature_label,
               goods_nomenclature: first_commodity,
               labels: {
                 'description' => 'A product description',
                 'known_brands' => [],
                 'colloquial_terms' => [],
                 'synonyms' => [],
               }

        create :goods_nomenclature_label,
               goods_nomenclature: second_commodity,
               labels: {
                 'description' => '',
                 'known_brands' => %w[BrandA BrandB],
                 'colloquial_terms' => [],
                 'synonyms' => [],
               }

        create :goods_nomenclature_label,
               goods_nomenclature: third_commodity,
               labels: {
                 'description' => 'Full description',
                 'known_brands' => %w[Brand],
                 'colloquial_terms' => ['common term'],
                 'synonyms' => %w[syn1 syn2],
               }
      end

      it 'counts total goods nomenclatures with labels' do
        expect(result.total_goods_nomenclatures).to eq(3)
      end

      it 'counts records with a description' do
        expect(result.descriptions_count).to eq(2)
      end

      it 'sums individual known brands across all records' do
        expect(result.known_brands_count).to eq(3)
      end

      it 'sums individual colloquial terms across all records' do
        expect(result.colloquial_terms_count).to eq(1)
      end

      it 'sums individual synonyms across all records' do
        expect(result.synonyms_count).to eq(2)
      end
    end

    context 'when distinguishing AI-created from human-edited' do
      let(:first_commodity) { create :commodity }
      let(:second_commodity) { create :commodity }

      before do
        create :goods_nomenclature_label,
               goods_nomenclature: first_commodity,
               labels: { 'description' => 'AI description' }

        create :goods_nomenclature_label,
               goods_nomenclature: second_commodity,
               labels: { 'description' => 'Human edited' },
               manually_edited: true
      end

      it 'counts AI-created labels' do
        expect(result.ai_created_only).to eq(1)
      end

      it 'counts human-edited labels' do
        expect(result.human_edited).to eq(1)
      end
    end

    context 'when labels have null or empty array values' do
      let(:commodity) { create :commodity }

      before do
        create :goods_nomenclature_label,
               goods_nomenclature: commodity,
               labels: {
                 'description' => nil,
                 'known_brands' => nil,
                 'colloquial_terms' => [],
                 'synonyms' => [],
               }
      end

      it 'does not count null description' do
        expect(result.descriptions_count).to eq(0)
      end

      it 'returns zero for null arrays' do
        expect(result.known_brands_count).to eq(0)
      end

      it 'returns zero for empty arrays' do
        expect(result.colloquial_terms_count).to eq(0)
        expect(result.synonyms_count).to eq(0)
      end
    end
  end
end
