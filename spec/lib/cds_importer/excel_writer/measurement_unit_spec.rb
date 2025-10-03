RSpec.describe CdsImporter::ExcelWriter::MeasurementUnit do
  subject(:mapper) { described_class.new(models) }

  let(:measurement_unit) do
    instance_double(
      MeasurementUnit,
      class: instance_double(Class, name: 'MeasurementUnit'),
      measurement_unit_code: 'GRT',
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:measurement_unit2) do
    instance_double(
      MeasurementUnit,
      class: instance_double(Class, name: 'MeasurementUnit'),
      measurement_unit_code: 'GRT',
      operation: 'C',
      validity_start_date: nil,
      validity_end_date: nil,
      )
  end

  let(:description) do
    instance_double(
      MeasurementUnitDescription,
      class: instance_double(Class, name: 'MeasurementUnitDescription'),
      description: 'Number of items',
    )
  end

  let(:description2) do
    instance_double(
      MeasurementUnitDescription,
      class: instance_double(Class, name: 'MeasurementUnitDescription'),
      description: nil,
      )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [measurement_unit, description] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new measurement unit code')
        expect(row[1]).to eq('GRT')
        expect(row[2]).to eq('01/01/2025')
        expect(row[3]).to eq('31/12/2025')
        expect(row[4]).to eq('Number of items')
      end
    end

    context 'when there are empty fields in measurement unit' do
      let(:models) { [measurement_unit2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new measurement unit code')
        expect(row[1]).to eq('GRT')
        expect(row[2]).to eq('')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
      end
    end

    context 'when the description is empty' do
      let(:models) { [measurement_unit2, description2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new measurement unit code')
        expect(row[1]).to eq('GRT')
        expect(row[2]).to eq('')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
      end
    end
  end
end
