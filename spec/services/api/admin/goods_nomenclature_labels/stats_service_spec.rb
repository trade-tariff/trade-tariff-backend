RSpec.describe Api::Admin::GoodsNomenclatureLabels::StatsService do
  subject(:service) { described_class.new }

  describe '#call' do
    let(:result) { service.call }

    context 'when there are no labels' do
      it 'returns zero counts' do
        expect(result).to eq(
          total_labels: 0,
          with_description: 0,
          with_known_brands: 0,
          with_colloquial_terms: 0,
          with_synonyms: 0,
          ai_created_only: 0,
          human_edited: 0,
        )
      end
    end

    context 'when there are labels with various attributes' do
      let(:commodity1) { create :commodity }
      let(:commodity2) { create :commodity }
      let(:commodity3) { create :commodity }

      before do
        # Label with description only
        create :goods_nomenclature_label,
               goods_nomenclature: commodity1,
               labels: {
                 'description' => 'A product description',
                 'known_brands' => [],
                 'colloquial_terms' => [],
                 'synonyms' => [],
               }

        # Label with known_brands
        create :goods_nomenclature_label,
               goods_nomenclature: commodity2,
               labels: {
                 'description' => '',
                 'known_brands' => %w[BrandA BrandB],
                 'colloquial_terms' => [],
                 'synonyms' => [],
               }

        # Label with all fields populated
        create :goods_nomenclature_label,
               goods_nomenclature: commodity3,
               labels: {
                 'description' => 'Full description',
                 'known_brands' => %w[Brand],
                 'colloquial_terms' => ['common term'],
                 'synonyms' => %w[syn1 syn2],
               }
      end

      it 'counts total labels' do
        expect(result[:total_labels]).to eq(3)
      end

      it 'counts labels with description' do
        expect(result[:with_description]).to eq(2)
      end

      it 'counts labels with known_brands' do
        expect(result[:with_known_brands]).to eq(2)
      end

      it 'counts labels with colloquial_terms' do
        expect(result[:with_colloquial_terms]).to eq(1)
      end

      it 'counts labels with synonyms' do
        expect(result[:with_synonyms]).to eq(1)
      end
    end

    context 'when distinguishing AI-created from human-edited' do
      let(:commodity1) { create :commodity }
      let(:commodity2) { create :commodity }

      before do
        # AI-created only (no updates)
        create :goods_nomenclature_label,
               goods_nomenclature: commodity1,
               labels: { 'description' => 'AI description' }

        # Human-edited (has an update)
        label = create :goods_nomenclature_label,
                       goods_nomenclature: commodity2,
                       labels: { 'description' => 'Original' }
        label.set(labels: { 'description' => 'Human edited' })
        label.save_update
        GoodsNomenclatureLabel.refresh!(concurrently: false)
      end

      it 'counts AI-created labels' do
        expect(result[:ai_created_only]).to eq(1)
      end

      it 'counts human-edited labels' do
        expect(result[:human_edited]).to eq(1)
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

      it 'does not count null description as having description' do
        expect(result[:with_description]).to eq(0)
      end

      it 'does not count null known_brands as having known_brands' do
        expect(result[:with_known_brands]).to eq(0)
      end

      it 'does not count empty arrays as having content' do
        expect(result[:with_colloquial_terms]).to eq(0)
        expect(result[:with_synonyms]).to eq(0)
      end
    end
  end
end
