RSpec.describe CdsImporter::ExcelWriter::Certificate do
  subject(:mapper) { described_class.new(models) }

  let(:certificate_type) do
    instance_double(
      Certificate,
      class: instance_double(Class, name: 'Certificate'),
      certificate_type_code: 'C',
      certificate_code: '121',
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:certificate_type2) do
    instance_double(
      Certificate,
      class: instance_double(Class, name: 'Certificate'),
      certificate_type_code: 'L',
      certificate_code: '212',
      operation: 'C',
      validity_start_date: nil,
      validity_end_date: nil,
    )
  end

  let(:description_period) do
    instance_double(
      CertificateDescriptionPeriod,
      class: instance_double(Class, name: 'CertificateDescriptionPeriod'),
      certificate_description_period_sid: 1,
      certificate_type_code: 'C',
      certificate_code: '121',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description_period2) do
    instance_double(
      CertificateDescriptionPeriod,
      class: instance_double(Class, name: 'CertificateDescriptionPeriod'),
      certificate_description_period_sid: 2,
      certificate_type_code: 'C',
      certificate_code: '121',
      validity_start_date: Time.utc(2023, 2, 2, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description) do
    instance_double(
      CertificateDescription,
      class: instance_double(Class, name: 'CertificateDescription'),
      certificate_description_period_sid: 1,
      certificate_type_code: 'C',
      certificate_code: '121',
      description: 'Information document',
    )
  end

  let(:description2) do
    instance_double(
      CertificateDescription,
      class: instance_double(Class, name: 'CertificateDescription'),
      certificate_description_period_sid: 2,
      certificate_type_code: 'C',
      certificate_code: '121',
      description: 'T5 control copy',
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [certificate_type, description, description_period, description2, description_period2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new certificate')
        expect(row[1]).to eq('C')
        expect(row[2]).to eq('121')
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq("01/01/2025\nInformation document\n02/02/2023\nT5 control copy\n")
      end
    end

    context 'when there is no description' do
      let(:models) { [certificate_type] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new certificate')
        expect(row[1]).to eq('C')
        expect(row[2]).to eq('121')
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq('')
      end
    end

    context 'when there are empty fields' do
      let(:models) { [certificate_type2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new certificate')
        expect(row[1]).to eq('L')
        expect(row[2]).to eq('212')
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
      end
    end
  end
end
