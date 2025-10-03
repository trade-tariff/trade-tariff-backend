RSpec.describe CdsImporter::ExcelWriter::MeasureType do
  subject(:mapper) { described_class.new(models) }

  let(:measure_type) do
    instance_double(
      MeasureType,
      class: instance_double(Class, name: 'MeasureType'),
      measure_type_id: '123456',
      trade_movement_code: 1,
      operation: 'C',
      priority_code: 5,
      origin_dest_code: 1,
      order_number_capture_code: 2,
      measure_component_applicable_code: 1,
      measure_explosion_level: 8,
      measure_type_series_id: '10',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:measure_type2) do
    instance_double(
      MeasureType,
      class: instance_double(Class, name: 'MeasureType'),
      measure_type_id: '123456',
      trade_movement_code: 1,
      operation: 'U',
      priority_code: 5,
      origin_dest_code: 1,
      order_number_capture_code: 2,
      measure_component_applicable_code: 1,
      measure_explosion_level: 8,
      measure_type_series_id: nil,
      validity_start_date: nil,
      validity_end_date: nil,
      )
  end

  let(:description) do
    instance_double(
      MeasureTypeDescription,
      class: instance_double(Class, name: 'MeasureTypeDescription'),
      description: 'Supplementary amount',
    )
  end

  let(:description2) do
    instance_double(
      MeasureTypeDescription,
      class: instance_double(Class, name: 'MeasureTypeDescription'),
      description: nil,
      )
  end


  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [measure_type, description] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new measure type')
        expect(row[1]).to eq('123456')
        expect(row[2]).to eq('01/01/2025')
        expect(row[3]).to eq('31/12/2025')
        expect(row[4]).to eq('Supplementary amount')
        expect(row[5]).to eq(1)
        expect(row[6]).to eq(1)
        expect(row[7]).to eq(1)
        expect(row[8]).to eq(2)
        expect(row[9]).to eq(8)
        expect(row[10]).to eq(5)
      end
    end

    context 'when there are empty fields in measure type' do
      let(:models) { [measure_type2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing measure type')
        expect(row[1]).to eq('123456')
        expect(row[2]).to eq('')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq(1)
        expect(row[6]).to eq(1)
        expect(row[7]).to eq(1)
        expect(row[8]).to eq(2)
        expect(row[9]).to eq(8)
        expect(row[10]).to eq(5)
      end
    end

    context 'when the description is empty' do
      let(:models) { [measure_type2, description2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing measure type')
        expect(row[1]).to eq('123456')
        expect(row[2]).to eq('')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq(1)
        expect(row[6]).to eq(1)
        expect(row[7]).to eq(1)
        expect(row[8]).to eq(2)
        expect(row[9]).to eq(8)
        expect(row[10]).to eq(5)
      end
    end
  end
end
