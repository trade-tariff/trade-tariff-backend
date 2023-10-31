RSpec.describe TaricImporter::RecordProcessor::UpdateOperation do
  subject(:build_update_operation) { described_class.new(record, operation_date).call }

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

    before do
      LanguageDescription.unrestrict_primary_key
    end

    context 'when record for update present' do
      before do
        create_language_description_record
      end

      it 'identifies as create operation', :aggregate_failures do
        build_update_operation

        expect(LanguageDescription.count).to eq 1
        expect(LanguageDescription.first.description).to eq 'French!'
      end

      it 'returns model instance even when the previous record is equal' do
        expect(build_update_operation).to be_kind_of LanguageDescription
      end

      it 'sets update operation date to operation_date' do
        build_update_operation

        expect(
          LanguageDescription::Operation.where(operation: 'U').first.operation_date,
        ).to eq operation_date
      end
    end

    context 'when record for update is missing' do
      it 'raises Sequel::RecordNotFound exception' do
        expect { build_update_operation }.to raise_error(Sequel::RecordNotFound)
      end

      context 'with ignoring presence errors' do
        before do
          allow(ActiveSupport::Notifications).to receive(:instrument)
        end

        it 'creates new record' do
          expect { build_update_operation }.to change(LanguageDescription, :count).from(0).to(1)
        end

        it 'sends presence error events' do
          build_update_operation
          expect(ActiveSupport::Notifications).to have_received(:instrument)
        end

        it 'invokes CreateOperation', :aggregate_failures do
          instance = instance_double(TaricImporter::RecordProcessor::CreateOperation)
          allow(TaricImporter::RecordProcessor::CreateOperation).to receive(:new).and_return(instance)
          allow(instance).to receive(:call)

          expect(instance).to have_received(:call)
          build_update_operation
        end
      end
    end

    def create_language_description_record
      create :language_description, language_code_id: 'FR', language_id: 'EN', description: 'French'
    end
  end
end
