require 'rails_helper'

describe TaricImporter::RecordProcessor::DestroyOperation do
  let(:record_hash) do
    { 'transaction_id' => '31946',
      'record_code' => '130',
      'subrecord_code' => '05',
      'record_sequence_number' => '1',
      'update_type' => '2',
      'language_description' =>
      { 'language_code_id' => 'FR',
        'language_id' => 'EN',
        'description' => 'French!' } }
  end

  describe '#call' do
    let(:operation_date) { Date.new(2013, 8, 1) }
    let(:record) do
      TaricImporter::RecordProcessor::Record.new(record_hash)
    end

    let(:operation) do
      TaricImporter::RecordProcessor::DestroyOperation.new(record, operation_date)
    end

    context 'record present for destroy' do
      before do
        create :language_description, language_code_id: 'FR',
                                      language_id: 'EN',
                                      description: 'French'

        LanguageDescription.unrestrict_primary_key
      end

      it 'identifies as create operation' do
        operation.call

        expect(LanguageDescription.count).to eq 0
      end

      it 'sets destroy operation date to operation_date' do
        operation.call

        expect(
          LanguageDescription::Operation.where(operation: 'D').first.operation_date,
        ).to eq operation_date
      end

      it 'returns model instance' do
        expect(operation.call).to be_kind_of LanguageDescription
      end
    end

    context 'record missing for destroy' do
      it 'raises Sequel::RecordNotFound exception' do
        expect { operation.call }.to raise_error(Sequel::RecordNotFound)
      end
    end
  end
end
