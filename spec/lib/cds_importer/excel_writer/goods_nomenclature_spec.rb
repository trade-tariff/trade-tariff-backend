RSpec.describe CdsImporter::ExcelWriter::GoodsNomenclature do
  subject(:mapper) { described_class.new(models) }

  let(:goods_nomenclature) do
    instance_double(
      GoodsNomenclature,
      class: instance_double(Class, name: 'GoodsNomenclature'),
      goods_nomenclature_item_id: '0102901010',
      producline_suffix: '80',
      statistical_indicator: 0,
      goods_nomenclature_sid: 1,
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:goods_nomenclature2) do
    instance_double(
      GoodsNomenclature,
      class: instance_double(Class, name: 'GoodsNomenclature'),
      goods_nomenclature_item_id: '0104108000',
      producline_suffix: '90',
      statistical_indicator: 1,
      goods_nomenclature_sid: 2,
      operation: 'C',
      validity_start_date: nil,
      validity_end_date: nil,
    )
  end

  let(:description_period) do
    instance_double(
      GoodsNomenclatureDescriptionPeriod,
      class: instance_double(Class, name: 'GoodsNomenclatureDescriptionPeriod'),
      goods_nomenclature_description_period_sid: 1,
      goods_nomenclature_sid: 1,
      productline_suffix: '80',
      goods_nomenclature_item_id: '0102901010',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description_period2) do
    instance_double(
      GoodsNomenclatureDescriptionPeriod,
      class: instance_double(Class, name: 'GoodsNomenclatureDescriptionPeriod'),
      goods_nomenclature_description_period_sid: 2,
      goods_nomenclature_sid: 2,
      productline_suffix: '90',
      goods_nomenclature_item_id: '0104108000',
      validity_start_date: Time.utc(2023, 2, 2, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description) do
    instance_double(
      GoodsNomenclatureDescription,
      class: instance_double(Class, name: 'GoodsNomenclatureDescription'),
      goods_nomenclature_description_period_sid: 1,
      goods_nomenclature_sid: 1,
      productline_suffix: '80',
      goods_nomenclature_item_id: '0102901010',
      description: 'Pure-bred breeding animals',
    )
  end

  let(:description2) do
    instance_double(
      GoodsNomenclatureDescription,
      class: instance_double(Class, name: 'GoodsNomenclatureDescription'),
      goods_nomenclature_description_period_sid: 2,
      goods_nomenclature_sid: 2,
      productline_suffix: '90',
      goods_nomenclature_item_id: '0104108000',
      description: 'Other',
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [goods_nomenclature, description, description_period, description2, description_period2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new commodity')
        expect(row[1]).to eq('0102901010')
        expect(row[2]).to eq('80')
        expect(row[3]).to eq("01/01/2025\nPure-bred breeding animals\n02/02/2023\nOther\n")
        expect(row[4]).to eq('01/01/2025')
        expect(row[5]).to eq('31/12/2025')
        expect(row[6]).to eq(0)
        expect(row[7]).to eq(1)
      end
    end

    context 'when there is no description' do
      let(:models) { [goods_nomenclature] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new commodity')
        expect(row[1]).to eq('0102901010')
        expect(row[2]).to eq('80')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('01/01/2025')
        expect(row[5]).to eq('31/12/2025')
        expect(row[6]).to eq(0)
        expect(row[7]).to eq(1)
      end
    end

    context 'when there are empty fields' do
      let(:models) { [goods_nomenclature2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new commodity')
        expect(row[1]).to eq('0104108000')
        expect(row[2]).to eq('90')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
        expect(row[6]).to eq(1)
        expect(row[7]).to eq(2)
      end
    end
  end
end
