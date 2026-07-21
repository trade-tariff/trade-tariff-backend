RSpec.describe TaricImporter::RecordProcessor::UpdateOperation do
  describe '#call' do
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
    let(:operation_date) { Date.new(2013, 8, 1) }
    let(:record) { TaricImporter::RecordProcessor::Record.new(record_hash) }
    let(:operation) { described_class.new(record, operation_date) }

    before do
      LanguageDescription.unrestrict_primary_key
    end

    context 'when record for update present' do
      before do
        create :language_description, language_code_id: 'FR', language_id: 'EN', description: 'French'
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

      it 'does not fall back to CreateOperation' do
        allow(TaricImporter::RecordProcessor::CreateOperation).to receive(:new)

        operation.call

        expect(TaricImporter::RecordProcessor::CreateOperation).not_to have_received(:new)
      end

      it 'does not create a create oplog row' do
        expect { operation.call }
          .not_to(change { LanguageDescription::Operation.where(operation: 'C').count })
      end
    end
  end

  describe 'when create is only present in the oplog' do
    let!(:seed_measure) { create(:measure) }
    let(:operation_date) { Date.new(2026, 5, 9) }
    let(:updated_end_date) { Date.new(2026, 12, 31) }

    let(:update_record) do
      TaricImporter::RecordProcessor::Record.new(
        'transaction_id' => '2',
        'record_code' => '430',
        'subrecord_code' => '00',
        'record_sequence_number' => '2',
        'update_type' => '1',
        'measure' => measure_attributes.merge(
          'validity_end_date' => updated_end_date.iso8601,
        ),
      )
    end

    let(:measure_attributes) do
      seed_measure
        .values
        .except(:oid, :operation, :operation_date, :filename, :created_at)
        .transform_keys(&:to_s)
        .merge(
          'measure_sid' => seed_measure.measure_sid.to_s,
          'validity_start_date' => seed_measure.validity_start_date&.iso8601,
          'validity_end_date' => seed_measure.validity_end_date&.iso8601,
        )
    end

    before do
      Measure.unrestrict_primary_key

      create_values = seed_measure
        .values
        .slice(*Measure.operation_klass.columns)
        .except(:oid)
        .merge(operation: 'C', operation_date:)

      Measure::Operation.where(measure_sid: seed_measure.measure_sid).delete
      Measure.refresh!(concurrently: false)
      Measure::Operation.insert(create_values)
    end

    it 'preserves same-file create then update as ordered oplog operations', :aggregate_failures do
      expect(Measure.where(measure_sid: seed_measure.measure_sid).first).to be_nil

      described_class.new(update_record, operation_date).call

      operations = Measure::Operation.where(measure_sid: seed_measure.measure_sid).order(:oid).select_map(:operation)
      expect(operations).to eq(%w[C U])

      update_op = Measure::Operation.where(measure_sid: seed_measure.measure_sid, operation: 'U').order(Sequel.desc(:oid)).first
      expect(update_op.operation_date).to eq(operation_date)
      expect(update_op.validity_end_date.to_date).to eq(updated_end_date)
    end
  end
end
