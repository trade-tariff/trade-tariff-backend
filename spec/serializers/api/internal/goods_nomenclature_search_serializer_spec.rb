RSpec.describe Api::Internal::GoodsNomenclatureSearchSerializer do
  it_behaves_like 'a serialized goods nomenclature search result', 'goods_nomenclature'

  describe '.serializer_for' do
    it 'returns ChapterSearchSerializer for Chapter class' do
      record = OpenStruct.new(goods_nomenclature_class: 'Chapter')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::ChapterSearchSerializer)
    end

    it 'returns HeadingSearchSerializer for Heading class' do
      record = OpenStruct.new(goods_nomenclature_class: 'Heading')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::HeadingSearchSerializer)
    end

    it 'returns SubheadingSearchSerializer for Subheading class' do
      record = OpenStruct.new(goods_nomenclature_class: 'Subheading')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::SubheadingSearchSerializer)
    end

    it 'returns CommoditySearchSerializer for Commodity class' do
      record = OpenStruct.new(goods_nomenclature_class: 'Commodity')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::CommoditySearchSerializer)
    end

    it 'returns self when goods_nomenclature_class is nil' do
      record = OpenStruct.new(goods_nomenclature_class: nil)
      expect(described_class.serializer_for(record)).to eq(described_class)
    end
  end

  describe '.serialize' do
    it 'returns a hash with data array' do
      result = described_class.serialize([])
      expect(result).to eq(data: [])
    end

    it 'serializes each record with the correct type-specific serializer' do
      chapter = OpenStruct.new(
        id: 1, goods_nomenclature_sid: 1, goods_nomenclature_item_id: '0100000000',
        producline_suffix: '80', goods_nomenclature_class: 'Chapter',
        description: 'animals', formatted_description: 'Animals',
        declarable: false, score: 10.0
      )
      heading = OpenStruct.new(
        id: 2, goods_nomenclature_sid: 2, goods_nomenclature_item_id: '0101000000',
        producline_suffix: '80', goods_nomenclature_class: 'Heading',
        description: 'horses', formatted_description: 'Horses',
        declarable: true, score: 8.5
      )

      result = described_class.serialize([chapter, heading])

      expect(result[:data].length).to eq(2)
      expect(result[:data][0][:type]).to eq(:chapter)
      expect(result[:data][1][:type]).to eq(:heading)
    end
  end
end
