RSpec.describe CdsImporter::ExcelWriter do
  subject(:writer) { described_class.new(filename) }

  let(:filename) { 'test.xlsx' }
  let(:entity1) do
    instance_double(
      CdsImporter::CdsEntity,
      key: 'K',
      element_id: 'E1',
      instance: 'I1',
    )
  end
  let(:entity2) do
    instance_double(
      CdsImporter::CdsEntity,
      key: 'K',
      element_id: 'E2',
      instance: 'I2',
    )
  end
  let(:excel) do
    instance_double(CdsImporter::ExcelWriter::QuotaDefinition,
                    sheet_name: 'Sheet 1',
                    note: [],
                    heading: [],
                    data_row: [],
                    table_span: [],
                    column_widths: [])
  end

  before do
    allow(Module).to receive(:const_get)
                       .with('CdsImporter::ExcelWriter::K')
                       .and_return(class_double(CdsImporter::ExcelWriter::QuotaDefinition, new: excel))
  end

  describe '#initialize' do
    it 'sets defaults and creates an excel file' do
      expect(writer.instance_variable_get(:@filename)).to eq(filename)
      expect(writer.instance_variable_get(:@xml_element_id)).to be_nil
      expect(writer.instance_variable_get(:@key)).to eq('')
      expect(writer.instance_variable_get(:@instances)).to eq([])
      expect(writer.instance_variable_get(:@workbook)).not_to be_nil
    end
  end

  describe 'write_record' do
    context 'when xml_element_id is nil' do
      it 'sets key, xml_element_id, and adds the instance' do
        writer.write_record(entity1)

        expect(excel).not_to have_received(:sheet_name)
        expect(writer.instance_variable_get(:@key)).to eq('K')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E1')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1])
      end
    end

    context 'when xml_element_id changes' do
      it 'writes existing instances and resets before adding new one' do
        writer.write_record(entity1)
        writer.write_record(entity2)

        expect(excel).to have_received(:sheet_name)
        expect(excel).to have_received(:note)
        expect(excel).to have_received(:sheet_name)
        expect(excel).to have_received(:heading)
        expect(excel).to have_received(:column_widths).exactly(2).times
        expect(excel).to have_received(:data_row)
        expect(writer.instance_variable_get(:@key)).to eq('K')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E2')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I2])
      end
    end

    context 'when xml_element_id stays the same' do
      it 'does not call write and accumulates instances' do
        writer.write_record(entity1)
        writer.write_record(entity1)

        expect(excel).not_to have_received(:sheet_name)
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1 I1])
      end
    end
  end
end
