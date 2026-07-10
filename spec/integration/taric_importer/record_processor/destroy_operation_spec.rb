RSpec.describe TaricImporter::RecordProcessor::DestroyOperation do
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
      described_class.new(record, operation_date)
    end

    context 'with record present for destroy' do
      before do
        create :language_description, language_code_id: 'FR',
                                      language_id: 'EN',
                                      description: 'French'

        LanguageDescription.unrestrict_primary_key
      end

      it 'writes a destroy operation for the record' do
        operation.call

        expect(
          LanguageDescription::Operation.where(operation: 'D').count,
        ).to eq 1
      end

      it 'sets destroy operation date to operation_date' do
        operation.call

        expect(
          LanguageDescription::Operation.where(operation: 'D').first.operation_date,
        ).to eq operation_date
      end

      it 'returns model instance' do
        expect(operation.call).to be_a LanguageDescription
      end
    end

    context 'when record missing for destroy' do
      before do
        LanguageDescription.unrestrict_primary_key
      end

      it 'writes a destroy operation from inbound attributes' do
        expect { operation.call }
          .to change { LanguageDescription::Operation.where(operation: 'D').count }.from(0).to(1)
      end

      it 'does not raise Sequel::RecordNotFound' do
        expect { operation.call }.not_to raise_error
      end
    end

    context 'when create is not yet visible in a materialized projection' do
      # Production TARIC apply writes create ops to the oplog without refreshing
      # materialized views between records. Seed a create row in measures_oplog
      # only, so the current measures projection does not contain the record.
      let!(:seed_measure) { create(:measure) }
      let(:measure_sid) { seed_measure.measure_sid }
      let(:operation_date) { Date.new(2026, 5, 9) }

      let(:destroy_record) do
        TaricImporter::RecordProcessor::Record.new(
          'transaction_id' => '2',
          'record_code' => '430',
          'subrecord_code' => '00',
          'record_sequence_number' => '2',
          'update_type' => '2',
          'measure' => measure_attributes,
        )
      end

      let(:measure_attributes) do
        seed_measure
          .values
          .except(:oid, :operation, :operation_date, :filename, :created_at)
          .transform_keys(&:to_s)
          .merge(
            'measure_sid' => measure_sid.to_s,
            'validity_start_date' => seed_measure.validity_start_date&.iso8601,
            'validity_end_date' => seed_measure.validity_end_date&.iso8601,
          )
      end

      before do
        Measure.unrestrict_primary_key

        # Replace factory state with an oplog-only create (no matview row).
        create_values = seed_measure
          .values
          .slice(*Measure.operation_klass.columns)
          .except(:oid)
          .merge(operation: 'C', operation_date:)

        Measure::Operation.where(measure_sid:).delete
        Measure.refresh!(concurrently: false)
        Measure::Operation.insert(create_values)
      end

      it 'preserves same-file create then destroy as ordered oplog operations', :aggregate_failures do
        expect(Measure.where(measure_sid:).first).to be_nil

        described_class.new(destroy_record, operation_date).call

        operations = Measure::Operation.where(measure_sid:).order(:oid).select_map(:operation)
        expect(operations).to eq(%w[C D])
      end
    end
  end
end
