RSpec.describe CdsImporter::RecordInserter do
  let(:measure_mapper) { CdsImporter::EntityMapper::MeasureMapper.new({}) }
  let(:certificate_mapper) { CdsImporter::EntityMapper::CertificateMapper.new({}) }

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
        .with('cds_importer.import.operations', mapper: measure_mapper, operation: expected_instrument_operation, count: 1, record:)
    end
  end

  shared_examples_for 'a batch insert operation' do |measure, certificate|
    subject(:do_insert) { described_class.new(batch, 'new_filename.gzip').save_batch }

    it 'persists a new record with the correct filename and operation' do
      expect {
        do_insert
      }.to change {
        Measure::Operation.where(operation: expected_db_operation, filename: 'new_filename.gzip').count
      }.by(measure)
       .and change {
         Certificate::Operation.where(operation: expected_db_operation, filename: 'new_filename.gzip').count
       }.by(certificate)
    end

    it 'calls instrument against ActiveSupport::Notifications' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

      do_insert

      expected_calls = batch.map do |entity|
        if entity.instance.skip_import?
          ['cds_importer.import.operations', { mapper: entity.mapper, operation: :skipped, count: 1, record: entity.instance }]
        else
          ['cds_importer.import.operations', { multi_insert: true, mapper: entity.mapper, operation: entity.instance.operation, count: 1, record: entity.instance }]
        end
      end

      expected_calls.each do |args|
        expect(ActiveSupport::Notifications).to have_received(:instrument).with(*args)
      end
    end
  end

  context 'when record batch is inserted' do
    let(:measure) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
    let(:certificate) { create(:certificate, filename: 'initial_filename.gzip', operation: 'C') }
    let(:expected_db_operation) { 'C' }
    let(:expected_instrument_operation) { :create }

    describe '#save_batch' do
      let(:measure2) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
      let(:batch) do
        [CdsImporter::CdsEntity.new('Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new('Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new('Measure', measure2, measure_mapper)]
      end

      it_behaves_like 'a batch insert operation', 2, 1
    end

    describe '#save_batch with skip record' do
      let(:measure2) { create(:measure, :with_skip_import, filename: 'initial_filename.gzip', operation: 'C') }
      let(:measure_entity2) { CdsImporter::CdsEntity.new('Measure', measure2, measure_mapper) }
      let(:batch) do
        [CdsImporter::CdsEntity.new('Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new('Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new('Measure', measure2, measure_mapper)]
      end

      it_behaves_like 'a batch insert operation', 1, 1
    end

    describe '#save_batch error scenario' do
      subject(:inserter) { described_class.new(batch, 'new_filename.gzip') }

      let(:measure2) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
      let(:measure_entity2) { CdsImporter::CdsEntity.new('Measure', measure2, measure_mapper) }
      let(:batch) do
        [CdsImporter::CdsEntity.new('Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new('Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new('Measure', measure2, measure_mapper)]
      end

      before do
        allow(measure.class.operation_klass).to receive(:multi_insert).and_raise(StandardError, 'Simulated error')
        allow(measure.class.operation_klass).to receive(:insert).and_call_original
      end

      it 'handles errors in save_group and calls save_single' do
        inserter.save_batch

        expect(measure.class.operation_klass).to have_received(:insert).at_least(:once)
      end

      it_behaves_like 'a batch insert operation', 2, 1
    end
  end

  context 'when single record is inserted' do
    let(:record) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
    let(:entity) { CdsImporter::CdsEntity.new('Measure', record, measure_mapper) }
    let(:batch) { [entity] }
    let(:args) { [] }

    describe '#save_record!' do
      let(:expected_db_operation) { 'C' } # Copied from record
      let(:expected_instrument_operation) { :create }
      let(:args) { [record, measure_mapper] }

      it_behaves_like 'an insert operation', :save_record!
    end

    describe '#save_record' do
      let(:expected_db_operation) { 'C' } # Copied from record
      let(:expected_instrument_operation) { :create }
      let(:args) { ['Measure', record, measure_mapper] }

      it_behaves_like 'an insert operation', :save_record

      context 'when an error is propagated' do
        subject(:do_insert) { described_class.new(batch, 'new_filename.gzip').save_record('Measure', record, measure_mapper) }

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
