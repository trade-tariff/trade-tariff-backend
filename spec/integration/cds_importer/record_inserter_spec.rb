RSpec.describe CdsImporter::RecordInserter do
  shared_examples_for 'an insert operation' do |method_name|
    subject(:do_insert) { described_class.new(batch, 'new_filename.gzip').public_send(method_name, *args) }

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

  context 'when record batch is inserted' do
    let(:mapper) { CdsImporter::EntityMapper::MeasureMapper.new({}) }
    let(:record) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
    let(:entity) { CdsImporter::CdsEntity.new('Measure', record, mapper) }
    let(:mapper2) { CdsImporter::EntityMapper::CertificateMapper.new({}) }
    let(:record2) { create(:certificate, filename: 'initial_filename.gzip', operation: 'C') }
    let(:entity2) { CdsImporter::CdsEntity.new('Certificate', record2, mapper2) }
    let(:batch) {[entity, entity2]}

    describe '#save_batch' do
      let(:expected_db_operation) { 'C' } # Copied from record
      let(:expected_instrument_operation) { :create }
      let(:args) { [] }

      it_behaves_like 'an insert operation', :save_batch
    end

  end

  context 'when single record is inserted' do

  let(:mapper) { CdsImporter::EntityMapper::MeasureMapper.new({}) }
  let(:record) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
  let(:entity) { CdsImporter::CdsEntity.new('Measure', record, mapper) }
  let(:batch) {[entity]}
  let(:args) { [] }

  describe '#save_record!' do
    let(:expected_db_operation) { 'C' } # Copied from record
    let(:expected_instrument_operation) { :create }
    let(:args) { [record, mapper] }

    it_behaves_like 'an insert operation', :save_record!
  end

  describe '#save_record' do
    let(:expected_db_operation) { 'C' } # Copied from record
    let(:expected_instrument_operation) { :create }
    let(:args) { ['Measure', record, mapper] }

    it_behaves_like 'an insert operation', :save_record

    context 'when an error is propagated' do
      subject(:do_insert) { described_class.new(batch, 'new_filename.gzip').save_record('Measure', record, mapper) }

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
end
