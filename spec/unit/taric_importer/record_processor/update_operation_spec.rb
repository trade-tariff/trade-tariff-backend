RSpec.describe TaricImporter::RecordProcessor::UpdateOperation do
  describe '#to_oplog_operation' do
    it 'identifies as update operation' do
      empty_operation = described_class.new(nil, nil)
      expect(empty_operation.to_oplog_operation).to eq :update
    end
  end

  describe '#call' do
    subject(:operation) { described_class.new(record, date) }

    let(:date) { Time.zone.today }
    let(:record) do
      TaricImporter::RecordProcessor::Record.new(
        'transaction_id' => '31946',
        'record_code' => '130',
        'subrecord_code' => '05',
        'record_sequence_number' => '1',
        'update_type' => '1',
        'language_description' => {
          'language_code_id' => 'FR',
          'language_id' => 'EN',
          'description' => 'French!',
        },
      )
    end

    before do
      LanguageDescription.unrestrict_primary_key
    end

    it 'writes an update oplog operation from inbound attributes' do
      expect { operation.call }
        .to change { LanguageDescription::Operation.where(operation: 'U').count }.by(1)
    end

    context 'when a primary key field is missing from the inbound attributes' do
      let(:record) do
        TaricImporter::RecordProcessor::Record.new(
          'transaction_id' => '31946',
          'record_code' => '130',
          'subrecord_code' => '05',
          'record_sequence_number' => '1',
          'update_type' => '1',
          'language_description' => {
            'language_code_id' => nil,
            'language_id' => 'EN',
            'description' => 'French!',
          },
        )
      end

      it 'raises rather than writing a partial oplog row' do
        expect { operation.call }.to raise_error(ArgumentError, /missing primary key fields/)
      end
    end
  end
end
