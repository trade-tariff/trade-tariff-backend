RSpec.describe TariffSynchronizer::Import::OperationTracker do
  subject(:tracker) { described_class.new(operation_keys: %i[create update destroy skipped]) }

  let(:mapper) { instance_double(TaricImporter::EntityMapper, entity_class: 'Measure') }

  describe '#track' do
    it 'runs the given block and returns its value' do
      value = tracker.track('taric_importer.import.operations', mapper:, operation: :create, count: 1) { 'inserted' }

      expect(value).to eq('inserted')
    end

    it 'records the operation, entity class and count against the result', :aggregate_failures do
      tracker.track('taric_importer.import.operations', mapper:, operation: :create, count: 3) { true }

      expect(tracker.result[:operations][:create]).to include(count: 3)
      expect(tracker.result[:operations][:create]['Measure']).to include(count: 3)
      expect(tracker.result[:total_count]).to eq(3)
    end

    it 'measures a positive duration around the block using the monotonic clock' do
      tracker.track('taric_importer.import.operations', mapper:, operation: :create, count: 1) { sleep 0.01 }

      expect(tracker.result[:total_duration]).to be > 0
    end

    it 'still records the operation when the block raises, then re-raises' do
      expect {
        tracker.track('taric_importer.import.operations', mapper:, operation: :create, count: 1) { raise 'boom' }
      }.to raise_error('boom')
    end

    it 'republishes a notification with the same payload shape used before the tracker existed' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original

      tracker.track('taric_importer.import.operations', mapper:, operation: :create, count: 1) { true }

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'taric_importer.import.operations',
        { mapper:, operation: :create, count: 1 },
      )
    end

    it 'does not publish a notification when publish_notifications is false' do
      silent_tracker = described_class.new(operation_keys: %i[create], publish_notifications: false)
      allow(ActiveSupport::Notifications).to receive(:instrument)

      silent_tracker.track('taric_importer.import.operations', mapper:, operation: :create, count: 1) { true }

      expect(ActiveSupport::Notifications).not_to have_received(:instrument)
    end
  end

  describe '#record' do
    it 'records without executing any block, with zero duration' do
      tracker.record('cds_importer.import.operations', mapper:, operation: :skipped, count: 1, record: double(identification: 'sid-1'))

      expect(tracker.result[:operations][:skipped]).to include(count: 1, duration: 0)
      expect(tracker.result[:operations][:skipped]['Measure'][:records]).to eq(%w[sid-1])
    end

    it 'republishes a notification including the record for skipped-style calls' do
      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      record = double(identification: 'sid-1')

      tracker.record('cds_importer.import.operations', mapper:, operation: :skipped, count: 1, record:)

      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'cds_importer.import.operations',
        { mapper:, operation: :skipped, count: 1, record: },
      )
    end
  end

  describe '#result' do
    it 'returns an Import::Result' do
      expect(tracker.result).to be_a(TariffSynchronizer::Import::Result)
    end
  end

  context 'when the mapper carries a mapping_path' do
    let(:mapper) { instance_double(CdsImporter::EntityMapper::MeasureMapper, entity_class: 'Measure', mapping_path: 'measure.path') }

    it 'records the mapping_path against the entity class bucket' do
      tracker.track('cds_importer.import.operations', mapper:, operation: :create, count: 1) { true }

      expect(tracker.result[:operations][:create]['Measure'][:mapping_path]).to eq('measure.path')
    end
  end
end
