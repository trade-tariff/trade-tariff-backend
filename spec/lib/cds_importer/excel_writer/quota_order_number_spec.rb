RSpec.describe CdsImporter::ExcelWriter::QuotaOrderNumber do
  subject(:mapper) { described_class.new(models) }

  let(:quota_order_number) do
    instance_double(
      QuotaOrderNumber,
      class: instance_double(Class, name: 'QuotaOrderNumber'),
      quota_order_number_sid: 1,
      quota_order_number_id: '095918',
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:quota_order_number2) do
    instance_double(
      QuotaOrderNumber,
      class: instance_double(Class, name: 'QuotaOrderNumber'),
      quota_order_number_sid: 2,
      quota_order_number_id: '090203',
      operation: 'U',
      validity_start_date: nil,
      validity_end_date: nil,
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [quota_order_number] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new quota order number')
        expect(row[1]).to eq(1)
        expect(row[2]).to eq('095918')
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
      end
    end

    context 'when there are empty fields in foot note type' do
      let(:models) { [quota_order_number2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing quota order number')
        expect(row[1]).to eq(2)
        expect(row[2]).to eq('090203')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
      end
    end
  end
end
