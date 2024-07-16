RSpec.describe TaricImporter::RecordProcessor::UpdateOperation do
  let(:record_hash) do
    { 'transaction_id' => '31946',
      'record_code' => '130',
      'subrecord_code' => '05',
      'record_sequence_number' => '1',
      'update_type' => '1',
      'language_description' =>
      { 'language_code_id' => 'FR',
        'language_id' => 'EN',
        'description' => 'French!' } }
  end

  describe '#call' do
    let(:operation_date) { Date.new(2013, 8, 1) }
    let(:record) { TaricImporter::RecordProcessor::Record.new(record_hash) }
    let(:operation) { build_update_operation }

    before do
      LanguageDescription.unrestrict_primary_key
    end

    context 'when record for update present' do
      before do
        create_language_description_record
      end

      it 'identifies as create operation' do
        operation.call
        expect(LanguageDescription.first.description).to eq 'French!'
      end

      it 'returns model instance' do
        expect(operation.call).to be_a LanguageDescription
      end

      it 'sets update operation date to operation_date' do
        operation.call
        expect(
          LanguageDescription::Operation.where(operation: 'U').first.operation_date,
        ).to eq operation_date
      end
    end

    context 'when record for update is missing' do
      it 'raises Sequel::RecordNotFound exception' do
        expect { operation.call }.to raise_error(Sequel::RecordNotFound)
      end

      context 'with ignoring presence errors' do
        before do
          allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(true)
        end

        it 'creates new record' do
          expect { operation.call }.to change(LanguageDescription, :count).from(0).to(1)
        end

        it 'sends presence error events' do
          allow(operation).to receive(:log_presence_error)
          operation.call
          expect(operation).to have_received(:log_presence_error)
        end

        it 'invokes CreateOperation' do
          instance = instance_double(TaricImporter::RecordProcessor::CreateOperation)
          allow(TaricImporter::RecordProcessor::CreateOperation).to receive(:new).and_return(instance)
          allow(instance).to receive(:call)
          operation.call

          expect(instance).to have_received(:call)
        end
      end
    end

    def build_update_operation
      TaricImporter::RecordProcessor::UpdateOperation.new(record, operation_date)
    end

    def create_language_description_record
      create :language_description, language_code_id: 'FR', language_id: 'EN', description: 'French'
    end
  end
end
