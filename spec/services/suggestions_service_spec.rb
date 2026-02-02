RSpec.describe SuggestionsService do
  subject(:call) { described_class.new.call }

  before do
    chapter = create(:chapter, goods_nomenclature_item_id: '0100000000')
    heading = create(:heading, goods_nomenclature_item_id: '0101000000', producline_suffix: '80')

    create(:heading, goods_nomenclature_item_id: '0102000000', producline_suffix: '10')
    create(:commodity, :non_declarable, goods_nomenclature_item_id: '0202070000')
    create(:commodity, :declarable, goods_nomenclature_item_id: '0202080001')

    create(:search_reference, referenced: chapter, title: 'gold Ore')
    create(:full_chemical, goods_nomenclature: heading)

    create(:full_chemical, goods_nomenclature: false) # We do not create chemical suggestions without goods nomenclature

    create(:chapter, :hidden, goods_nomenclature_item_id: '0200000000')
    create(:heading, :hidden, goods_nomenclature_item_id: '0202000000')
    create(:commodity, :hidden, goods_nomenclature_item_id: '0202090000')
  end

  let(:expected_values) do
    [
      '01',
      '0101',
      '020207',
      '0202080001',
      'gold ore', # search reference
      'mel powder', # chemical
      '8028-66-8', # chemical
      '0154438-3', # chemical
    ]
  end

  let(:expected_goods_nomenclature_classes) do
    [
      'Chapter',
      'Heading',
      'Subheading',
      'Commodity',
      'Chapter', # search reference
      'Heading', # chemical
      'Heading', # chemical
      'Heading', # chemical
    ]
  end

  it { expect(call.map(&:value)).to eq(expected_values) }

  it { expect(call.map(&:goods_nomenclature_class)).to eq(expected_goods_nomenclature_classes) }

  context 'with label-based suggestions' do
    before do
      commodity = create(:commodity, :declarable, goods_nomenclature_item_id: '0303110000')
      create(
        :goods_nomenclature_label,
        goods_nomenclature: commodity,
        labels: {
          'known_brands' => %w[BrandA BrandB],
          'colloquial_terms' => ['slang term'],
          'synonyms' => %w[alias],
        },
      )
    end

    it 'includes label-based suggestion types' do
      types = call.map(&:type)
      expect(types).to include('known_brand', 'colloquial_term', 'synonym')
    end

    it 'includes the correct values' do
      label_values = call.select { |s| %w[known_brand colloquial_term synonym].include?(s.type) }.map(&:value)
      expect(label_values).to contain_exactly('branda', 'brandb', 'slang term', 'alias')
    end
  end

  context 'with duplicate terms in labels' do
    before do
      commodity = create(:commodity, :declarable, goods_nomenclature_item_id: '0404110000')
      create(
        :goods_nomenclature_label,
        goods_nomenclature: commodity,
        labels: {
          'known_brands' => %w[Samsung Samsung samsung SAMSUNG],
          'colloquial_terms' => [],
          'synonyms' => [],
        },
      )
    end

    it 'deduplicates terms by normalized value' do
      brand_suggestions = call.select { |s| s.type == 'known_brand' }
      expect(brand_suggestions.map(&:value)).to eq(%w[samsung])
    end
  end
end
