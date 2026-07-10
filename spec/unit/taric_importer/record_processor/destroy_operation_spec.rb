RSpec.describe TaricImporter::RecordProcessor::DestroyOperation do
  subject(:operation) { described_class.new(record, date) }

  let(:date) { Time.zone.today }
  let(:record) do
    TaricImporter::RecordProcessor::Record.new(record_hash)
  end

  let(:record_hash) do
    { 'transaction_id' => '31946',
      'record_code' => '130',
      'subrecord_code' => '05',
      'record_sequence_number' => '1',
      'update_type' => '2',
      'language_description' =>
         { 'language_code_id' => 'FR',
           'language_id' => 'EN',
           'description' => 'French' } }
  end

  describe '#to_oplog_operation' do
    let(:date) { nil }
    let(:record) { nil }

    it 'identifies as destroy operation' do
      expect(operation.to_oplog_operation).to eq :destroy
    end
  end

  describe '#call' do
    before do
      LanguageDescription.unrestrict_primary_key
    end

    context 'when a current record is present' do
      before do
        LanguageDescription.create(
          'language_code_id' => 'FR',
          'language_id' => 'EN',
          'description' => 'French',
        )
      end

      it 'writes a destroy oplog operation' do
        expect { operation.call }
          .to change { LanguageDescription::Operation.where(operation: 'D').count }.by(1)
      end

      it 'returns the model record' do
        expect(operation.call).to be_a(LanguageDescription)
      end
    end

    context 'when no current record is present' do
      it 'still writes a destroy oplog operation from the inbound attributes' do
        expect { operation.call }
          .to change { LanguageDescription::Operation.where(operation: 'D').count }.from(0).to(1)
      end

      it 'returns the model record' do
        expect(operation.call).to be_a(LanguageDescription)
      end
    end
  end
end
