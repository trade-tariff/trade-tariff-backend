RSpec.describe CdsImporter::ExcelWriter::FootnoteType do
  subject(:mapper) { described_class.new(models) }

  let(:footnote_type) do
    instance_double(
      FootnoteType,
      class: instance_double(Class, name: 'FootnoteType'),
      footnote_type_id: 'PN',
      application_code: 2,
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description) do
    instance_double(
      FootnoteTypeDescription,
      class: instance_double(Class, name: 'FootnoteTypeDescription'),
      description: 'Dynamic footnote',
    )
  end

  let(:footnote_type2) do
    instance_double(
      FootnoteType,
      class: instance_double(Class, name: 'FootnoteType'),
      footnote_type_id: 'CD',
      application_code: 7,
      operation: 'U',
      validity_start_date: nil,
      validity_end_date: nil,
    )
  end

  let(:description2) do
    instance_double(
      FootnoteTypeDescription,
      class: instance_double(Class, name: 'FootnoteTypeDescription'),
      description: nil,
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [footnote_type, description] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new footnote type')
        expect(row[1]).to eq('PN')
        expect(row[2]).to eq(2)
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq('Dynamic footnote')
      end
    end

    context 'when there are empty fields in footnote type' do
      let(:models) { [footnote_type2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing footnote type')
        expect(row[1]).to eq('CD')
        expect(row[2]).to eq(7)
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
      end
    end

    context 'when the description is empty' do
      let(:models) { [footnote_type2, description2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Update an existing footnote type')
        expect(row[1]).to eq('CD')
        expect(row[2]).to eq(7)
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
      end
    end
  end
end
