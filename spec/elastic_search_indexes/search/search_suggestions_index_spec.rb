RSpec.describe Search::SearchSuggestionsIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'goods_nomenclature' }
  it { is_expected.to have_attributes name: 'tariff-test-search_suggestions-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'SearchSuggestionsIndex' }
  it { is_expected.to have_attributes model_class: GoodsNomenclature }
  it { is_expected.to have_attributes serializer: Search::SearchSuggestionsSerializer }

  describe '#definition' do
    subject(:definition) { instance.definition }

    it 'includes labels mapping' do
      labels_mapping = definition.dig(:mappings, :properties, :labels)
      expect(labels_mapping).to be_present
      expect(labels_mapping[:properties].keys).to include(:description, :known_brands, :colloquial_terms, :synonyms)
    end
  end
end
