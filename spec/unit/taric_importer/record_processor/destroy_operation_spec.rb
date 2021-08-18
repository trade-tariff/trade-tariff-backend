describe TaricImporter::RecordProcessor::DestroyOperation do
  let(:empty_operation) do
    TaricImporter::RecordProcessor::DestroyOperation.new(nil, nil)
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

  let(:record) do
    TaricImporter::RecordProcessor::Record.new(record_hash)
  end

  let(:operation) do
    TaricImporter::RecordProcessor::DestroyOperation.new(record, Date.current)
  end

  describe '#to_oplog_operation' do
    it 'identifies as destroy operation' do
      expect(empty_operation.to_oplog_operation).to eq :destroy
    end
  end

  describe '#ignore_presence_errors?' do
    it 'returns true if presence ignored' do
      allow(TariffSynchronizer).to receive(:ignore_presence_errors).and_return(true)
      expect(empty_operation.send(:ignore_presence_errors?)).to be_truthy
    end
  end

  describe '#get_model_record' do
    context 'with ignoring presence on destroy' do
      before do
        allow(TariffSynchronizer).to receive(:ignore_presence_errors).and_return(true)
      end

      it 'gets model record' do
        expect(LanguageDescription).to receive_message_chain(:filter, :first)
        operation.send(:get_model_record)
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

        it 'returns a model record' do
          record = operation.send(:get_model_record)
          expect(record.language_code_id).to eq('FR')
          expect(record).to be_a(LanguageDescription)
        end
      end
    end

    context 'with NOT ignoring presence on destroy' do
      before do
        allow(TariffSynchronizer).to receive(:ignore_presence_errors).and_return(false)
      end

      it 'gets model record' do
        expect(LanguageDescription).to receive_message_chain(:filter, :take)
        operation.send(:get_model_record)
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

        it 'returns a model record' do
          record = operation.send(:get_model_record)
          expect(record.language_code_id).to eq('FR')
          expect(record).to be_a(LanguageDescription)
        end
      end
    end
  end

  describe '#call' do
    context 'if record is found' do
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
        record = operation.call
        expect(record).to be_a(LanguageDescription)
        expect(record.language_code_id).to eq('FR')
      end

      it 'does not send presence error events' do
        expect(operation).not_to receive(:log_presence_error)
        operation.call
      end
    end

    context 'if record is not found' do
      before do
        allow(TariffSynchronizer).to receive(:ignore_presence_errors).and_return(true)
      end

      it 'sends presence error events' do
        expect(operation).to receive(:log_presence_error)
        operation.call
      end

      it 'returns nil' do
        expect(operation.call).to be_nil
      end
    end
  end
end
