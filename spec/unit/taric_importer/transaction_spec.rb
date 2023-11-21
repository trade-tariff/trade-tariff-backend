RSpec.describe TaricImporter::Transaction do
  let(:record) do
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
  let(:transaction_date) { Time.zone.today }

  describe 'initialization' do
    context 'with invalid record structure provided' do
      it 'raises an ArgumentError exception' do
        expect { described_class.new({}) }.to raise_error ArgumentError
      end
    end
  end

  describe '#persist' do
    it 'instantiates RecordProcessor class and calls the process! method', :aggregate_failures do
      record_processor_instance = instance_double(TaricImporter::RecordProcessor)
      allow(TaricImporter::RecordProcessor).to receive(:new)
                                                .with(record, transaction_date)
                                                .and_return(record_processor_instance)
      allow(record_processor_instance).to receive(:process!)
      described_class.new(record, transaction_date).persist

      expect(record_processor_instance).to have_received(:process!)
      expect(TaricImporter::RecordProcessor).to have_received(:new)
                                                .with(record, transaction_date)
    end
  end
end
