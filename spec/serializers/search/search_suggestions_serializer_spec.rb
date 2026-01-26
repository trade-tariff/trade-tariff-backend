RSpec.describe Search::SearchSuggestionsSerializer do
  describe '#to_json' do
    subject(:serialized) { described_class.new(serializable).to_json }

    let(:serializable) { create(:commodity, :with_ancestors, :with_description) }

    let(:pattern) do
      {
        goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
        description: 'Horses, other than lemmings',
      }.ignore_extra_keys!
    end

    it { is_expected.to match_json_expression pattern }
  end

  describe '#labels_part' do
    subject(:serializer) { described_class.new(serializable) }

    let(:serializable) { create(:commodity, :with_ancestors, :with_description) }

    context 'when goods_nomenclature_label is present' do
      before do
        create(:goods_nomenclature_label,
               goods_nomenclature_sid: serializable.goods_nomenclature_sid,
               goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
               producline_suffix: serializable.producline_suffix,
               goods_nomenclature_type: 'Commodity',
               labels: {
                 'description' => 'AI enhanced description',
                 'known_brands' => %w[BrandA BrandB],
                 'colloquial_terms' => ['common name'],
                 'synonyms' => %w[synonym1 synonym2],
               })
        serializable.reload
      end

      it 'includes labels in serialized output' do
        result = serializer.serializable_hash
        expect(result[:labels]).to be_present
        expect(result[:labels][:description]).to eq('AI enhanced description')
        expect(result[:labels][:known_brands]).to eq(%w[BrandA BrandB])
        expect(result[:labels][:colloquial_terms]).to eq(['common name'])
        expect(result[:labels][:synonyms]).to eq(%w[synonym1 synonym2])
      end
    end

    context 'when goods_nomenclature_label is not present' do
      it 'does not include labels in serialized output' do
        result = serializer.serializable_hash
        expect(result).not_to have_key(:labels)
      end
    end
  end
end
