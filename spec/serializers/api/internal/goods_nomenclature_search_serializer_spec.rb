RSpec.describe Api::Internal::GoodsNomenclatureSearchSerializer do
  let(:serializer_for_record_class) { Data.define(:goods_nomenclature_class) }
  let(:search_record_class) do
    Data.define(
      :id,
      :goods_nomenclature_sid,
      :goods_nomenclature_item_id,
      :producline_suffix,
      :goods_nomenclature_class,
      :description,
      :formatted_description,
      :self_text,
      :classification_description,
      :full_description,
      :heading_description,
      :confidence,
      :declarable,
      :score,
    )
  end

  it_behaves_like 'a serialized goods nomenclature search result', 'goods_nomenclature'

  describe '.serializer_for' do
    it 'returns ChapterSearchSerializer for Chapter class' do
      record = serializer_for_record_class.new(goods_nomenclature_class: 'Chapter')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::ChapterSearchSerializer)
    end

    it 'returns HeadingSearchSerializer for Heading class' do
      record = serializer_for_record_class.new(goods_nomenclature_class: 'Heading')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::HeadingSearchSerializer)
    end

    it 'returns SubheadingSearchSerializer for Subheading class' do
      record = serializer_for_record_class.new(goods_nomenclature_class: 'Subheading')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::SubheadingSearchSerializer)
    end

    it 'returns CommoditySearchSerializer for Commodity class' do
      record = serializer_for_record_class.new(goods_nomenclature_class: 'Commodity')
      expect(described_class.serializer_for(record)).to eq(Api::Internal::CommoditySearchSerializer)
    end

    it 'returns self when goods_nomenclature_class is nil' do
      record = serializer_for_record_class.new(goods_nomenclature_class: nil)
      expect(described_class.serializer_for(record)).to eq(described_class)
    end
  end

  describe '.serialize' do
    it 'returns a hash with data array' do
      result = described_class.serialize([])
      expect(result).to eq(data: [])
    end

    it 'serializes each record with the correct type-specific serializer' do
      chapter = search_record_class.new(
        id: 1, goods_nomenclature_sid: 1, goods_nomenclature_item_id: '0100000000',
        producline_suffix: '80', goods_nomenclature_class: 'Chapter',
        description: 'animals', formatted_description: 'Animals',
        self_text: nil, classification_description: nil, full_description: nil, heading_description: nil, confidence: nil,
        declarable: false, score: 10.0
      )
      heading = search_record_class.new(
        id: 2, goods_nomenclature_sid: 2, goods_nomenclature_item_id: '0101000000',
        producline_suffix: '80', goods_nomenclature_class: 'Heading',
        description: 'horses', formatted_description: 'Horses',
        self_text: nil, classification_description: nil, full_description: nil, heading_description: nil, confidence: nil,
        declarable: true, score: 8.5
      )

      result = described_class.serialize([chapter, heading])

      expect(result[:data].length).to eq(2)
      expect(result[:data][0][:type]).to eq(:chapter)
      expect(result[:data][1][:type]).to eq(:heading)
    end
  end
end
