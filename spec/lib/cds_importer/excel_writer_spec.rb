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
  let(:entity3) do
    instance_double(
      CdsImporter::CdsEntity,
      key: 'NotExist',
      element_id: 'E2',
      instance: 'I2',
    )
  end
  let(:excel) do
    instance_double(CdsImporter::ExcelWriter::QuotaDefinition,
                    valid?: true,
                    data_row: [])
  end

  let(:excel_class) do
    class_double(CdsImporter::ExcelWriter::QuotaDefinition,
                 sheet_name: 'Sheet 1',
                 note: [],
                 heading: [],
                 table_span: [],
                 column_widths: [],
                 new: excel)
  end

  before do
    allow(Module).to receive(:const_get)
                       .with('CdsImporter::ExcelWriter::K')
                       .and_return(excel_class)

    allow(Module).to receive(:const_get)
                       .with('CdsImporter::ExcelWriter::NotExist').and_raise(NameError)
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

  describe 'process_record' do
    context 'when xml_element_id is nil' do
      it 'sets key, xml_element_id, and adds the instance' do
        writer.process_record(entity1)

        expect(excel_class).not_to have_received(:sheet_name)
        expect(writer.instance_variable_get(:@key)).to eq('K')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E1')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1])
      end
    end

    context 'when xml_element_id changes' do
      it 'writes existing instances and resets before adding new one' do
        writer.process_record(entity1)
        writer.process_record(entity2)

        expect(excel).to have_received(:data_row)
        expect(writer.instance_variable_get(:@key)).to eq('K')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E2')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I2])
      end
    end

    context 'when xml_element_id stays the same' do
      it 'does not call write and accumulates instances' do
        writer.process_record(entity1)
        writer.process_record(entity1)

        expect(excel_class).not_to have_received(:sheet_name)
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1 I1])
      end
    end
  end

  describe 'handle invalid cds entity' do
    it 'handles key that not mapped' do
      writer.process_record(entity3)
      writer.process_record(entity1)

      expect(excel_class).not_to have_received(:sheet_name)
      expect(writer.instance_variable_get(:@key)).to eq('K')
      expect(writer.instance_variable_get(:@xml_element_id)).to eq('E1')
      expect(writer.instance_variable_get(:@instances)).to eq(%w[I1])
    end
  end
end
