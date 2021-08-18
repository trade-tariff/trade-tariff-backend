describe TaricImporter::RecordProcessor::UpdateOperation do
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

    context 'record for update present' do
      before do
        create_language_description_record
      end

      it 'identifies as create operation' do
        operation.call
        expect(LanguageDescription.count).to eq 1
        expect(LanguageDescription.first.description).to eq 'French!'
      end

      it 'returns model instance' do
        expect(operation.call).to be_kind_of LanguageDescription
      end

      it 'returns model instance even when the previous record is equal' do
        expect(operation.call).to be_kind_of LanguageDescription
      end

      it 'sets update operation date to operation_date' do
        operation.call
        expect(
          LanguageDescription::Operation.where(operation: 'U').first.operation_date,
        ).to eq operation_date
      end
    end

    context 'record for update missing' do
      it 'raises Sequel::RecordNotFound exception' do
        expect { operation.call }.to raise_error(Sequel::RecordNotFound)
      end

      context 'with ignoring presence errors' do
        before do
          allow(TariffSynchronizer).to receive(:ignore_presence_errors).and_return(true)
        end

        it 'creates new record' do
          expect { operation.call }.to change(LanguageDescription, :count).from(0).to(1)
        end

        it 'sends presence error events' do
          expect(operation).to receive(:log_presence_error)
          operation.call
        end

        it 'invokes CreateOperation' do
          expect_any_instance_of(TaricImporter::RecordProcessor::CreateOperation).to receive(:call)
          operation.call
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
