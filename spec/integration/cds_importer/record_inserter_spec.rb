RSpec.describe CdsImporter::RecordInserter do
  shared_examples_for 'an insert operation' do |method_name|
    subject(:do_insert) { described_class.new(record, mapper, 'new_filename.gzip').public_send(method_name, *args) }

    it 'persists a new record with the correct filename and operation' do
      expect { do_insert }
        .to change { Measure::Operation.where(operation: expected_db_operation, filename: 'new_filename.gzip').count }
        .by(1)
    end

    it 'calls instrument against ActiveSupport::Notifications' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

      do_insert

      expect(ActiveSupport::Notifications)
        .to have_received(:instrument)
        .with('cds_importer.import.operations', mapper:, operation: expected_instrument_operation, count: 1, record:)
    end
  end

  let(:mapper) { CdsImporter::EntityMapper::MeasureMapper.new({}) }
  let(:record) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
  let(:args) { [] }

  describe '#save_record!' do
    let(:expected_db_operation) { 'C' } # Copied from record
    let(:expected_instrument_operation) { :create }

    it_behaves_like 'an insert operation', :save_record!
  end

  describe '#save_record' do
    let(:expected_db_operation) { 'C' } # Copied from record
    let(:expected_instrument_operation) { :create }
    let(:args) { %w[Measure] }

    it_behaves_like 'an insert operation', :save_record

    context 'when an error is propagated' do
      subject(:do_insert) { described_class.new(record, mapper, 'new_filename.gzip').save_record('Measure') }

      before do
        allow(record.class.operation_klass).to receive(:insert).and_raise(StandardError, 'foo')
      end

      it { expect(do_insert).to be_nil }

      it 'calls instrument against ActiveSupport::Notifications' do
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

        do_insert

        expect(ActiveSupport::Notifications)
          .to have_received(:instrument)
          .with('cds_error.cds_importer', record:, xml_key: 'Measure', xml_node: {}, exception: an_instance_of(StandardError))
      end
    end
  end
end
