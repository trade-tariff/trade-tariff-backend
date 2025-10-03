RSpec.describe CdsImporter::ExcelWriter::Footnote do
  subject(:mapper) { described_class.new(models) }

  let(:footnote_type) do
    instance_double(
      Footnote,
      class: instance_double(Class, name: 'Footnote'),
      footnote_type_id: 'PN',
      footnote_id: '2',
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:footnote_type2) do
    instance_double(
      Footnote,
      class: instance_double(Class, name: 'Footnote'),
      footnote_type_id: 'PN',
      footnote_id: '2',
      operation: 'C',
      validity_start_date: nil,
      validity_end_date: nil,
    )
  end

  let(:description_period) do
    instance_double(
      FootnoteDescriptionPeriod,
      class: instance_double(Class, name: 'FootnoteDescriptionPeriod'),
      footnote_description_period_sid: 1,
      footnote_type_id: 'PN',
      footnote_id: '2',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description_period2) do
    instance_double(
      FootnoteDescriptionPeriod,
      class: instance_double(Class, name: 'FootnoteDescriptionPeriod'),
      footnote_description_period_sid: 2,
      footnote_type_id: 'PN',
      footnote_id: '2',
      validity_start_date: Time.utc(2023, 2, 2, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description) do
    instance_double(
      FootnoteDescription,
      class: instance_double(Class, name: 'FootnoteDescription'),
      footnote_description_period_sid: 1,
      footnote_type_id: 'PN',
      footnote_id: '2',
      description: 'Within the limits of an annual Community ceiling.',
    )
  end

  let(:description2) do
    instance_double(
      FootnoteDescription,
      class: instance_double(Class, name: 'FootnoteDescription'),
      footnote_description_period_sid: 2,
      footnote_type_id: 'PN',
      footnote_id: '2',
      description: 'Per 1% by weight of sucrose.',
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [footnote_type, description, description_period, description2, description_period2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new footnote')
        expect(row[1]).to eq('PN2')
        expect(row[2]).to eq('PN')
        expect(row[3]).to eq('2')
        expect(row[4]).to eq('01/01/2025')
        expect(row[5]).to eq('31/12/2025')
        expect(row[6]).to eq("01/01/2025\nWithin the limits of an annual Community ceiling.\n02/02/2023\nPer 1% by weight of sucrose.\n")
      end
    end

    context 'when there is no description' do
      let(:models) { [footnote_type] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new footnote')
        expect(row[1]).to eq('PN2')
        expect(row[2]).to eq('PN')
        expect(row[3]).to eq('2')
        expect(row[4]).to eq('01/01/2025')
        expect(row[5]).to eq('31/12/2025')
        expect(row[6]).to eq('')
      end
    end

    context 'when there are empty fields' do
      let(:models) { [footnote_type2] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new footnote')
        expect(row[1]).to eq('PN2')
        expect(row[2]).to eq('PN')
        expect(row[3]).to eq('2')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
        expect(row[6]).to eq('')
      end
    end
  end
end
