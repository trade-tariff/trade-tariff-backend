RSpec.describe CdsImporter::RecordInserter do
  let(:measure_mapper) { CdsImporter::EntityMapper::MeasureMapper.new({}) }
  let(:certificate_mapper) { CdsImporter::EntityMapper::CertificateMapper.new({}) }

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
          ['cds_importer.import.operations', { mapper: entity.mapper, operation: entity.instance.operation, count: 1, record: entity.instance }]
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
      let(:certificate2) { create(:certificate, filename: 'initial_filename.gzip', operation: 'C') }
      let(:batch) do
        [CdsImporter::CdsEntity.new('Measure', measure, measure_mapper),
         CdsImporter::CdsEntity.new('Certificate', certificate, certificate_mapper),
         CdsImporter::CdsEntity.new('Certificate', certificate2, certificate_mapper),
         CdsImporter::CdsEntity.new('Measure', measure2, measure_mapper)]
      end

      before do
        allow(measure.class.operation_klass).to receive(:multi_insert).and_raise(StandardError, 'Simulated error')
      end

      it 'handles errors in save_group' do
        inserter.save_batch

        expect(measure.class.operation_klass).to have_received(:multi_insert).at_least(:once)
      end

      it_behaves_like 'a batch insert operation', 0, 2
    end
  end
end
