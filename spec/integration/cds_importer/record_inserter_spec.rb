RSpec.describe CdsImporter::RecordInserter do
  let(:measure_mapper) { CdsImporter::EntityMapper::MeasureMapper.new({}) }
  let(:certificate_mapper) { CdsImporter::EntityMapper::CertificateMapper.new({}) }

  shared_examples_for 'a batch insert operation' do |measure, certificate|
    subject(:inserter) { described_class.new('new_filename.gzip') }

    let(:do_insert) do
      batch.each do |record|
        inserter.insert_record(record)
      end
      inserter.process_batch
    end

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

    it 'calls skip instrument against ActiveSupport::Notifications' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

      do_insert

      batch.map do |entity|
        if entity.instance.skip_import?
          args = ['cds_importer.import.operations', { mapper: entity.mapper, operation: :skipped, count: 1, record: entity.instance }]
          expect(ActiveSupport::Notifications).to have_received(:instrument).with(*args)
        end
      end
    end

    it 'calls instrument against ActiveSupport::Notifications' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

      do_insert

      filtered_batch = batch.reject { |entity| entity.instance.skip_import? }
      groups = filtered_batch.group_by { |entity| entity.instance.class.operation_klass }
      groups.each_value do |group|
        first_entity = group.first
        args = ['cds_importer.import.operations', { mapper: first_entity.mapper, operation: first_entity.instance.operation, count: group.size }]
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
        [CdsImporter::CdsEntity.new(1, 'Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new(2, 'Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new(3, 'Measure', measure2, measure_mapper)]
      end

      it_behaves_like 'a batch insert operation', 2, 1
    end

    describe '#save_batch with skip record' do
      let(:measure2) { create(:measure, :with_skip_import, filename: 'initial_filename.gzip', operation: 'C') }
      let(:batch) do
        [CdsImporter::CdsEntity.new(1, 'Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new(2, 'Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new(3, 'Measure', measure2, measure_mapper)]
      end

      it_behaves_like 'a batch insert operation', 1, 1
    end

    describe '#save_batch error scenario' do
      subject(:inserter) { described_class.new('new_filename.gzip') }

      let(:measure2) { create(:measure, filename: 'initial_filename.gzip', operation: 'C') }
      let(:certificate2) { create(:certificate, filename: 'initial_filename.gzip', operation: 'C') }
      let(:batch) do
        [CdsImporter::CdsEntity.new(1, 'Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new(2, 'Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new(3, 'Certificate', certificate2, certificate_mapper),
         CdsImporter::CdsEntity.new(4, 'Measure', measure2, measure_mapper)]
      end

      before do
        allow(measure.class.operation_klass).to receive(:multi_insert).and_raise(StandardError, 'Simulated error')
      end

      it 'handles errors in save_group' do
        batch.each do |record|
          inserter.insert_record(record)
        end
        inserter.process_batch

        expect(measure.class.operation_klass).to have_received(:multi_insert).at_least(:once)
      end

      it_behaves_like 'a batch insert operation', 0, 2
    end
  end
end
