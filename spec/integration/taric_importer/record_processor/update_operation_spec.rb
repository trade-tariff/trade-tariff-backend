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

      it 'writes an update operation with the new attributes' do
        operation.call
        expect(
          LanguageDescription::Operation.where(operation: 'U').order(Sequel.desc(:oid)).first.description,
        ).to eq 'French!'
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
      it 'writes an update operation from inbound attributes' do
        expect { operation.call }
          .to change { LanguageDescription::Operation.where(operation: 'U').count }.from(0).to(1)
      end

      it 'does not raise Sequel::RecordNotFound' do
        expect { operation.call }.not_to raise_error
      end

      it 'does not fall back to CreateOperation' do
        allow(TaricImporter::RecordProcessor::CreateOperation).to receive(:new)

        operation.call

        expect(TaricImporter::RecordProcessor::CreateOperation).not_to have_received(:new)
      end

      it 'does not send presence error events' do
        events = []
        subscriber = ActiveSupport::Notifications.subscribe(/presence_error/) do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        operation.call

        expect(events).to be_empty
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
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
