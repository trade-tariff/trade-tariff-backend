RSpec.describe Cache::SearchCacheMethods do
  let :serializer_class do
    Class.new do
      include Cache::SearchCacheMethods
    end
  end

  let(:serializer) { serializer_class.new }

  describe '#goods_nomenclature_attributes' do
    subject(:goods_nomenclature_attributes) { serializer.goods_nomenclature_attributes(goods_nomenclature) }

    context 'when the goods nomenclature is present' do
      let(:goods_nomenclature) { create(:heading) }

      let(:expected_pattern) do
        {
          id: goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature_class: 'Heading',
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          number_indents: 0,
          description: '',
          formatted_description: nil,
          producline_suffix: '80',
          validity_start_date: goods_nomenclature.validity_start_date,
          validity_end_date: nil,
        }
      end

      it { expect(goods_nomenclature_attributes).to eq(expected_pattern) }
    end

    context 'when the goods nomenclature is blank' do
      let(:goods_nomenclature) { nil }
      let(:expected_pattern) { nil }

      it { expect(goods_nomenclature_attributes).to eq(expected_pattern) }
    end
  end

  describe '#geographical_area_attributes' do
    subject(:geographical_area_attributes) { serializer.geographical_area_attributes(geographical_area) }

    context 'when the geographical area is present' do
      let(:geographical_area) { create(:geographical_area, :with_description) }

      let(:expected_pattern) do
        {
          id: geographical_area.geographical_area_id,
          description: 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.',
          geographical_area_id: geographical_area.geographical_area_id,
        }
      end

      it { expect(geographical_area_attributes).to eq(expected_pattern) }
    end

    context 'when the geographical area is blank' do
      let(:geographical_area) { nil }
      let(:expected_pattern) { nil }

      it { expect(geographical_area_attributes).to eq(expected_pattern) }
    end
  end
end
