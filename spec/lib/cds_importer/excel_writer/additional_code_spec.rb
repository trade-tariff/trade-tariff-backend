RSpec.describe CdsImporter::ExcelWriter::AdditionalCode do
  subject(:mapper) { described_class.new(models) }

  def model(model_class, **attributes)
    instance_double(model_class, class: instance_double(Class, name: model_class.name), **attributes)
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) do
        [
          model(
            AdditionalCode,
            additional_code_type_id: 'A',
            additional_code: '507',
            operation: 'C',
            validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
            validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
          ),
          model(
            AdditionalCodeDescription,
            additional_code_description_period_sid: 1,
            additional_code_sid: 1,
            additional_code_type_id: 'A',
            additional_code: '507',
            description: 'Other',
          ),
          model(
            AdditionalCodeDescriptionPeriod,
            additional_code_description_period_sid: 1,
            additional_code_sid: 1,
            additional_code_type_id: 'A',
            additional_code: '507',
            validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
            validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
          ),
          model(
            AdditionalCodeDescription,
            additional_code_description_period_sid: 2,
            additional_code_sid: 1,
            additional_code_type_id: 'A',
            additional_code: '507',
            description: 'Brother Industries Ltd.',
          ),
          model(
            AdditionalCodeDescriptionPeriod,
            additional_code_description_period_sid: 2,
            additional_code_sid: 1,
            additional_code_type_id: 'A',
            additional_code: '507',
            validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
            validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
          ),
        ]
      end

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new additional code')
        expect(row[1]).to eq('A')
        expect(row[2]).to eq('507')
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq("01/01/2025\nOther\n01/01/2025\nBrother Industries Ltd.\n")
      end
    end

    context 'when there is no description' do
      let(:models) do
        [model(
          AdditionalCode,
          additional_code_type_id: 'A',
          additional_code: '507',
          operation: 'C',
          validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
          validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
        )]
      end

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new additional code')
        expect(row[1]).to eq('A')
        expect(row[2]).to eq('507')
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq('')
      end
    end

    context 'when there are empty fields' do
      let(:models) do
        [
          model(
            AdditionalCode,
            additional_code_type_id: 'A',
            additional_code: '507',
            operation: 'U',
            validity_start_date: nil,
            validity_end_date: nil,
          ),
          model(
            AdditionalCodeDescriptionPeriod,
            additional_code_description_period_sid: 1,
            additional_code_sid: 1,
            additional_code_type_id: 'A',
            additional_code: '507',
            validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
            validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
          ),
        ]
      end

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing additional code')
        expect(row[1]).to eq('A')
        expect(row[2]).to eq('507')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
      end
    end
  end
end
