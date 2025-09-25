RSpec.describe CdsImporter::ExcelWriter do
  subject(:writer) { described_class.new(filename) }

  let(:filename) { 'test.xlsx' }

  let(:entity1) do
    instance_double(
      :cds_entity,
      key: 'K1',
      element_id: 'E1',
      instance: 'I1',
    )
  end

  let(:entity2) do
    instance_double(
      :cds_entity,
      key: 'K2',
      element_id: 'E2',
      instance: 'I2',
    )
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

        expect(writer.instance_variable_get(:@key)).to eq('K1')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E1')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1])
      end
    end

    context 'when xml_element_id changes' do
      it 'writes existing instances and resets before adding new one' do
        allow(writer).to receive(:write)

        writer.write_record(entity1)
        writer.write_record(entity2)

        expect(writer).to have_received(:write).with('K1', %w[I1])
        expect(writer.instance_variable_get(:@key)).to eq('K2')
        expect(writer.instance_variable_get(:@xml_element_id)).to eq('E2')
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I2])
      end
    end

    context 'when xml_element_id stays the same' do
      it 'does not call write and accumulates instances' do
        allow(writer).to receive(:write)

        writer.write_record(entity1)
        writer.write_record(entity1)

        expect(writer).not_to have_received(:write)
        expect(writer.instance_variable_get(:@instances)).to eq(%w[I1 I1])
      end
    end
  end
end
