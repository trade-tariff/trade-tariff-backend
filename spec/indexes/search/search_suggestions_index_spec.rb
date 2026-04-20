RSpec.describe Search::SearchSuggestionsIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'search_suggestion' }
  it { is_expected.to have_attributes name: 'tariff-test-search_suggestions-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'SearchSuggestionsIndex' }
  it { is_expected.to have_attributes model_class: SearchSuggestion }
  it { is_expected.to have_attributes serializer: Search::SearchSuggestionsSerializer }

  describe '#document_id' do
    it 'returns a composite id from model id and md5 of value' do
      SearchSuggestion.unrestrict_primary_key
      model = SearchSuggestion.new
      model.id = 123
      model.value = 'test value'

      expected = "123:#{Digest::MD5.hexdigest('test value')}"
      expect(instance.document_id(model)).to eq(expected)
    end
  end

  describe '#definition' do
    subject(:definition) { instance.definition }

    it 'includes value mapping with ngram analyzer' do
      value_mapping = definition.dig(:mappings, :properties, :value)
      expect(value_mapping).to be_present
      expect(value_mapping[:type]).to eq('text')
      expect(value_mapping[:analyzer]).to eq('ngram_analyzer')
      expect(value_mapping.dig(:fields, :keyword, :type)).to eq('keyword')
    end

    it 'includes suggestion_type as keyword' do
      expect(definition.dig(:mappings, :properties, :suggestion_type, :type)).to eq('keyword')
    end

    it 'includes priority as integer' do
      expect(definition.dig(:mappings, :properties, :priority, :type)).to eq('integer')
    end

    it 'includes goods_nomenclature_sid as long' do
      expect(definition.dig(:mappings, :properties, :goods_nomenclature_sid, :type)).to eq('long')
    end

    it 'includes goods_nomenclature_class as keyword' do
      expect(definition.dig(:mappings, :properties, :goods_nomenclature_class, :type)).to eq('keyword')
    end

    it 'includes ngram analyzer settings' do
      analyzers = definition.dig(:settings, :analysis, :analyzer)
      expect(analyzers).to have_key(:ngram_analyzer)
      expect(analyzers).to have_key(:lowercase_analyzer)
    end
  end
end
