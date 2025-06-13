require 'rails_helper'

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

      expect(record_processor.record).to be_a TaricImporter::RecordProcessor::Record
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

    context 'when the operation is unknown' do
      it 'raises TaricImporter::UnknownOperation exception' do
        expect { record_processor.operation_class = 'error' }.to raise_error TaricImporter::UnknownOperationError
      end
    end
  end

  describe '#process!' do
    context 'with default operation' do
      before do
        allow(TaricImporter::RecordProcessor::CreateOperation).to receive(:new).and_return(create_operation)
      end

      let(:create_operation) do
        instance_double(
          TaricImporter::RecordProcessor::CreateOperation,
          call: true,
          to_oplog_operation: :create
        )
      end

      it 'performs default create operation' do
        record_processor.process!

        expect(create_operation).to have_received(:call)
      end
    end

    context 'with custom operation' do
      before do
        stub_const(
          'TaricImporter::RecordProcessor::OperationOverrides::LanguageDescriptionCreateOperation',
          create_operation_class,
        )
        allow(TaricImporter::RecordProcessor::OperationOverrides::LanguageDescriptionCreateOperation).to receive(:new).and_return(create_operation)
      end

      let(:create_operation_class) do
        Class.new do
          def initialize(_record, _operation_date); end

          def call
            true
          end
        end
      end

      let(:create_operation) do
        instance_double(
          create_operation_class,
          call: true,
          to_oplog_operation: :create
        )
      end


      it 'performs ovverriding create operation' do
        record_processor.process!

        expect(create_operation).to have_received :call
      end
    end
  end
end
