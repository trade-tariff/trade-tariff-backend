RSpec.describe TaricImporter::RecordProcessor::CreateOperation do
  subject(:create_operation) { described_class.new(record, operation_date).call }

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

  describe '#call' do
    let(:operation_date) { Date.new(2013, 8, 1) }
    let(:record) do
      TaricImporter::RecordProcessor::Record.new(record_hash)
    end

    before do
      LanguageDescription.unrestrict_primary_key
    end

    it 'identifies as create operation', :aggregate_failures do
      expect(LanguageDescription.count).to eq 0
      create_operation
      expect(LanguageDescription.count).to eq 1
    end

    it 'returns model instance' do
      expect(create_operation).to be_a LanguageDescription
    end

    it 'sets create operation date to operation_date' do
      create_operation

      expect(
        LanguageDescription::Operation.where(operation: 'C').first.operation_date,
      ).to eq operation_date
    end
  end
end
