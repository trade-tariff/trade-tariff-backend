RSpec.describe CdsImporter::ExcelWriter::BaseRegulation do
  subject(:mapper) { described_class.new(models) }

  let(:base_regulation) do
    instance_double(
      BaseRegulation,
      class: instance_double(Class, name: 'BaseRegulation'),
      base_regulation_id: '1',
      information_text: 'MESU 103 (Chap. 10)',
      regulation_group_id: '5',
      base_regulation_role: 9,
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:base_regulation2) do
    instance_double(
      BaseRegulation,
      class: instance_double(Class, name: 'BaseRegulation'),
      base_regulation_id: '1',
      information_text: 'MESU 103 (Chap. 10)',
      regulation_group_id: '5',
      base_regulation_role: 9,
      operation: 'U',
      validity_start_date: nil,
      validity_end_date: nil,
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [base_regulation] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new base regulation')
        expect(row[1]).to eq('1')
        expect(row[2]).to eq('MESU 103 (Chap. 10)')
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('5')
        expect(row[5]).to eq(9)
      end
    end

    context 'when there are empty fields in foot note type' do
      let(:models) { [base_regulation2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing base regulation')
        expect(row[1]).to eq('1')
        expect(row[2]).to eq('MESU 103 (Chap. 10)')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('5')
        expect(row[5]).to eq(9)
      end
    end
  end
end
