class TestSearchCacheSerializer
  include Cache::SearchCacheMethods

  attr_reader :as_of

  def initialize(as_of)
    @as_of = as_of
  end
end

RSpec.describe Cache::SearchCacheMethods do
  let(:serializer) { TestSearchCacheSerializer.new(Date.parse(as_of)) }
  let(:as_of) { '2021-01-01' }

  describe '#has_valid_dates' do
    subject(:has_valid_dates) { serializer.has_valid_dates(record_hash) }

    let(:record_hash) do
      {
        validity_start_date: '2021-01-01',
        validity_end_date: '2021-01-03',
      }
    end

    context 'when the as of date is before the range' do
      let(:as_of) { '2020-12-31' }

      it { is_expected.to be(false) }
    end

    context 'when the as of date is on the start of the range' do
      let(:as_of) { '2021-01-01' }

      it { is_expected.to be(true) }
    end

    context 'when the as of date is on the end of the range' do
      let(:as_of) { '2021-01-03' }

      it { is_expected.to be(true) }
    end

    context 'when the as of date is after the range' do
      let(:as_of) { '2021-01-04' }

      it { is_expected.to be(false) }
    end
  end

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
          formatted_description: '',
          producline_suffix: '80',
          validity_start_date: '2020-03-22T00:00:00.000Z',
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
      let(:geographical_area) { create(:geographical_area) }

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
