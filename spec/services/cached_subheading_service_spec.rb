RSpec.describe CachedSubheadingService do
  subject(:service) { described_class.new(subheading, actual_date) }

  let(:subheading) { Subheading.find(goods_nomenclature_item_id: '0101290000', producline_suffix: '80') }
  let(:actual_date) { '2021-01-01' }

  before do
    GoodsNomenclature.unrestrict_primary_key

    create(:chapter, :with_section, :with_indent, :with_guide, goods_nomenclature_sid: 1, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0100000000')       # Live animals
    create(:heading, :with_indent, :with_description, goods_nomenclature_sid: 2, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')   # Live horses, asses, mules and hinnies
    create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 3, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') # Horses
    create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 4, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101210000') # -- Pure-bred breeding animals
    create(:commodity, :with_indent, :with_description, :with_overview_measures, goods_nomenclature_sid: 5, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101290000') # -- Other
    create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 6, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101291000') # ---- For slaughter
    create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 7, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101299000') # ---- Other
    create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 8, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101300000') # Asses
    create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 9, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101900000') # Other
  end

  describe '#call' do
    let(:pattern) do
      {
        data: {
          id: subheading.goods_nomenclature_sid.to_s,
          type: 'subheading',
          attributes: {
            goods_nomenclature_item_id: subheading.code,
            description: String,
            formatted_description: String,
          }.ignore_extra_keys!,
          relationships: {
            section: Hash,
            heading: Hash,
            commodities: Hash,
            chapter: Hash,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!,
      }.ignore_extra_keys!
    end

    let(:actual_commodities) do
      commodities = service.call[:included].select { |include| include[:type] == :commodity }

      commodities.map do |commodity|
        commodity[:attributes].slice(
          :goods_nomenclature_item_id,
          :productline_suffix,
          :number_indents,
          :parent_sid,
          :leaf,
        )
      end
    end

    it 'returns a correctly serialized hash' do
      expect(service.call.to_json).to match_json_expression(pattern)
    end

    it 'surfaces and annotates the correct commodities' do
      expected_commodities = [
        { goods_nomenclature_item_id: '0101210000', productline_suffix: '10', number_indents: 1, parent_sid: nil, leaf: false }, # Horses
        { goods_nomenclature_item_id: '0101290000', productline_suffix: '80', number_indents: 2, parent_sid: 3, leaf: false },   # -- Other < targeted subheading
        { goods_nomenclature_item_id: '0101291000', productline_suffix: '80', number_indents: 3, parent_sid: 5, leaf: true },    # ---- For slaughter
        { goods_nomenclature_item_id: '0101299000', productline_suffix: '80', number_indents: 3, parent_sid: 5, leaf: true },    # ---- Other
      ]

      expect(actual_commodities).to eq(expected_commodities)
    end

    it 'caches with the correct key' do
      allow(Rails.cache).to receive(:fetch).and_call_original
      service.call.to_json
      expect(Rails.cache).to have_received(:fetch).with("_subheading-#{subheading.goods_nomenclature_sid}-2021-01-01", expires_in: 23.hours)
    end
  end
end
