RSpec.describe Search::GoodsNomenclatureIndex do
  subject(:instance) { described_class.new }

  it { is_expected.to have_attributes model_class: GoodsNomenclature }
  it { is_expected.to have_attributes serializer: Search::GoodsNomenclatureSerializer }
  it { is_expected.to have_attributes name_without_namespace: 'GoodsNomenclatureIndex' }

  describe '#name' do
    it 'uses goods_nomenclatures as the index name' do
      expect(instance.name).to match(/goods_nomenclatures/)
    end
  end

  describe '#definition' do
    subject(:definition) { instance.definition }

    it 'includes presentational fields as keyword/non-searchable' do
      properties = definition.dig(:mappings, :properties)

      expect(properties[:goods_nomenclature_sid]).to eq(type: 'long')
      expect(properties[:goods_nomenclature_item_id]).to eq(type: 'keyword')
      expect(properties[:producline_suffix]).to eq(type: 'keyword')
      expect(properties[:chapter_short_code]).to eq(type: 'keyword')
      expect(properties[:heading_short_code]).to eq(type: 'keyword')
      expect(properties[:declarable]).to eq(type: 'boolean')
      expect(properties[:goods_nomenclature_class]).to eq(type: 'keyword')
      expect(properties[:formatted_description]).to eq(type: 'keyword', index: false)
    end

    it 'includes searchable text fields' do
      properties = definition.dig(:mappings, :properties)

      expect(properties[:description]).to eq(type: 'text', analyzer: 'snowball')
      expect(properties[:ancestor_descriptions]).to eq(type: 'text', analyzer: 'snowball')
      expect(properties[:search_references]).to eq(type: 'text', analyzer: 'snowball')
    end

    it 'includes labels mapping' do
      labels = definition.dig(:mappings, :properties, :labels, :properties)

      expect(labels).to include(:description, :known_brands, :colloquial_terms, :synonyms)
    end
  end

  describe '#eager_load' do
    it 'includes required associations for serialization' do
      associations = instance.eager_load.flatten

      expect(associations).to include(
        :goods_nomenclature_indents,
        :goods_nomenclature_descriptions,
        :goods_nomenclature_label,
        :search_references,
      )
    end

    it 'includes ancestors with descriptions' do
      ancestor_config = instance.eager_load.find { |e| e.is_a?(Hash) && e.key?(:ancestors) }

      expect(ancestor_config).to be_present
      expect(ancestor_config[:ancestors]).to include(:goods_nomenclature_descriptions)
    end
  end
end
