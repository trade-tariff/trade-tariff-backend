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

  describe '#ignore_presence_errors?' do
    let(:date) { nil }
    let(:record) { nil }

    it 'returns true if presence ignored' do
      allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(true)
      expect(operation.send(:ignore_presence_errors?)).to be_truthy
    end
  end

  describe '#get_model_record' do
    context 'with ignoring presence on destroy' do
      before do
        allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(true)
      end

      it 'gets model filtered record' do
        filter_result = double
        allow(LanguageDescription).to receive(:filter).and_return(filter_result)
        allow(filter_result).to receive(:first)

        operation.send(:get_model_record)

        expect(LanguageDescription).to have_received(:filter)
      end

      it 'gets model first record' do
        filter_result = double
        allow(LanguageDescription).to receive(:filter).and_return(filter_result)
        allow(filter_result).to receive(:first)

        operation.send(:get_model_record)

        expect(filter_result).to have_received(:first)
      end

      context 'when record is NOT found' do
        it 'returns nil' do
          record = operation.send(:get_model_record)
          expect(record).to be_nil
        end
      end

      context 'when record is found' do
        before do
          LanguageDescription.unrestrict_primary_key
          LanguageDescription.create('language_code_id' => 'FR',
                                     'language_id' => 'EN',
                                     'description' => 'French')
        end

        it 'returns a model record', :aggregate_failures do
          record = operation.send(:get_model_record)
          expect(record).to be_a(LanguageDescription)
        end

        it 'returns a model record code id' do
          record = operation.send(:get_model_record)
          expect(record.language_code_id).to eq('FR')
        end
      end
    end

    context 'with NOT ignoring presence on destroy' do
      before do
        allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(false)
      end

      it 'gets model record and filter' do
        filter_result = double
        allow(LanguageDescription).to receive(:filter).and_return(filter_result)
        allow(filter_result).to receive(:take)

        operation.send(:get_model_record)

        expect(LanguageDescription).to have_received(:filter)
      end

      it 'gets model record and called take' do
        filter_result = double
        allow(LanguageDescription).to receive(:filter).and_return(filter_result)
        allow(filter_result).to receive(:take)

        operation.send(:get_model_record)

        expect(filter_result).to have_received(:take)
      end

      context 'when record is NOT found' do
        it 'returns a model record' do
          expect { operation.send(:get_model_record) }.to raise_exception(Sequel::RecordNotFound)
        end
      end

      context 'when record is found' do
        before do
          LanguageDescription.unrestrict_primary_key
          LanguageDescription.create('language_code_id' => 'FR',
                                     'language_id' => 'EN',
                                     'description' => 'French')
        end

        it 'returns a model record', :aggregate_failures do
          record = operation.send(:get_model_record)
          expect(record).to be_a(LanguageDescription)
        end

        it 'returns a model record code id' do
          record = operation.send(:get_model_record)
          expect(record.language_code_id).to eq('FR')
        end
      end
    end
  end

  describe '#call' do
    context 'when record is found' do
      before do
        LanguageDescription.unrestrict_primary_key
        LanguageDescription.create('language_code_id' => 'FR',
                                   'language_id' => 'EN',
                                   'description' => 'French')
      end

      it 'destroys the record ' do
        expect { operation.call }.to change(LanguageDescription, :count).from(1).to(0)
      end

      it 'returns the model record' do
        expect(operation.call).to be_a(LanguageDescription)
      end

      it 'returns the model record code id' do
        record = operation.call
        expect(record.language_code_id).to eq('FR')
      end

      # rubocop:disable RSpec/SubjectStub
      it 'does not sends presence error events' do
        allow(operation).to receive(:log_presence_error)
        operation.call
        expect(operation).not_to have_received(:log_presence_error)
      end
    end

    context 'when record is not found' do
      before do
        allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(true)
      end

      it 'sends presence error events' do
        allow(operation).to receive(:log_presence_error)
        operation.call
        expect(operation).to have_received(:log_presence_error)
      end
      # rubocop:enable RSpec/SubjectStub

      it 'returns nil' do
        expect(operation.call).to be_nil
      end
    end
  end
end
