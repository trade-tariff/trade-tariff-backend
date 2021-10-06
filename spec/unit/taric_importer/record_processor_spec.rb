require 'rails_helper'

require 'taric_importer'
require 'taric_importer/record_processor'
require 'taric_importer/record_processor/create_operation'

RSpec.describe TaricImporter::RecordProcessor do
  subject(:record_processor) { described_class.new(record_hash, Date.new(2013, 8, 1)) }

  let(:record_hash) do
    { 'transaction_id' => '31946',
      'record_code' => '130',
      'subrecord_code' => '05',
      'record_sequence_number' => '1',
      'update_type' => '3',
      'language_description' =>
      { 'language_code_id' => 'FR',
        'language_id' => 'EN',
        'description' => 'French' } }
  end

  describe '#record=' do
    it 'instantiates a Record' do
      record_processor.record = record_hash

      expect(record_processor.record).to be_kind_of TaricImporter::RecordProcessor::Record
    end
  end

  describe '#operation_class=' do
    context 'with update identifier' do
      before { record_processor.operation_class = '1' }

      it 'assigns UpdateOperation' do
        expect(record_processor.operation_class).to eq TaricImporter::RecordProcessor::UpdateOperation
      end
    end

    context 'with destroy identifier' do
      before { record_processor.operation_class = '2' }

      it 'assigns DestroyOperation' do
        expect(record_processor.operation_class).to eq TaricImporter::RecordProcessor::DestroyOperation
      end
    end

    context 'with create identifier' do
      before { record_processor.operation_class = '3' }

      it 'assigns CreateOperation' do
        expect(record_processor.operation_class).to eq TaricImporter::RecordProcessor::CreateOperation
      end
    end

    context 'unknown operation' do
      it 'raises TaricImporter::UnknownOperation exception' do
        expect { record_processor.operation_class = 'error' }.to raise_error TaricImporter::UnknownOperationError
      end
    end
  end

  describe '#process!' do
    context 'with default processor' do
      it 'performs default create operation' do
        create_operation_intance = instance_double(TaricImporter::RecordProcessor::CreateOperation, call: true)
        expect(TaricImporter::RecordProcessor::CreateOperation).to receive(:new)
                                                                   .and_return(create_operation_intance)
        expect(create_operation_intance).to receive(:call)
        record_processor.process!
      end
    end

    context 'with custom processor' do
      it 'performs model type specific create operation' do
        custom_operation_instance = double('instance of LanguageDescriptionCreateOperation', call: true)
        custom_create_operation_class = double('LanguageDescriptionCreateOperation', new: custom_operation_instance)
        stub_const('TaricImporter::RecordProcessor::LanguageDescriptionCreateOperation', custom_create_operation_class)

        record_processor = described_class.new(record_hash, Date.new(2013, 8, 1))
        record_processor.process!

        expect(custom_create_operation_class).to have_received :new
        expect(custom_operation_instance).to     have_received :call
      end
    end
  end
end
