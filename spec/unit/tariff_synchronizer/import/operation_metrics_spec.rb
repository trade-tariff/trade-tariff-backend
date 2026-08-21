RSpec.describe TariffSynchronizer::Import::OperationMetrics do
  subject(:metrics) { described_class.new(%i[create update destroy skipped]) }

  describe '#result' do
    it 'starts with every operation key zeroed' do
      expect(metrics.result[:operations]).to eq(
        create: { count: 0, duration: 0 },
        update: { count: 0, duration: 0 },
        destroy: { count: 0, duration: 0 },
        skipped: { count: 0, duration: 0 },
      )
      expect(metrics.result[:total_count]).to eq(0)
      expect(metrics.result[:total_duration]).to eq(0)
    end
  end

  describe '#record' do
    it 'accumulates count and duration under the operation and entity class' do
      metrics.record(operation: :create, entity_class: 'Measure', count: 3, duration: 1.5)

      expect(metrics.result[:operations][:create]).to include(count: 3, duration: 1.5)
      expect(metrics.result[:operations][:create]['Measure']).to eq(count: 3, duration: 1.5)
      expect(metrics.result[:total_count]).to eq(3)
      expect(metrics.result[:total_duration]).to eq(1.5)
    end

    it 'accumulates across multiple calls for the same operation and entity class' do
      metrics.record(operation: :create, entity_class: 'Measure', count: 3, duration: 1.0)
      metrics.record(operation: :create, entity_class: 'Measure', count: 2, duration: 0.5)

      expect(metrics.result[:operations][:create]).to include(count: 5, duration: 1.5)
      expect(metrics.result[:operations][:create]['Measure']).to eq(count: 5, duration: 1.5)
    end

    it 'keeps separate entity class breakdowns under the same operation' do
      metrics.record(operation: :create, entity_class: 'Measure', count: 1, duration: 0.1)
      metrics.record(operation: :create, entity_class: 'Certificate', count: 2, duration: 0.2)

      expect(metrics.result[:operations][:create]['Measure']).to eq(count: 1, duration: 0.1)
      expect(metrics.result[:operations][:create]['Certificate']).to eq(count: 2, duration: 0.2)
      expect(metrics.result[:operations][:create]).to include(count: 3, duration: 0.30000000000000004)
    end

    it 'ignores non-positive counts' do
      metrics.record(operation: :create, entity_class: 'Measure', count: 0, duration: 1.0)

      expect(metrics.result[:operations][:create]).to include(count: 0, duration: 0)
      expect(metrics.result[:total_count]).to eq(0)
    end

    it 'records a mapping_path from metadata against the entity class bucket' do
      metrics.record(operation: :create, entity_class: 'Measure', count: 1, duration: 0.1, metadata: { mapping_path: 'measure.path' })

      expect(metrics.result[:operations][:create]['Measure'][:mapping_path]).to eq('measure.path')
    end

    it 'appends record identifiers from metadata under a records array' do
      metrics.record(operation: :skipped, entity_class: 'Measure', count: 1, duration: 0, metadata: { record_identifier: 'sid-1' })
      metrics.record(operation: :skipped, entity_class: 'Measure', count: 1, duration: 0, metadata: { record_identifier: 'sid-2' })

      expect(metrics.result[:operations][:skipped]['Measure'][:records]).to eq(%w[sid-1 sid-2])
    end

    it 'raises for an operation key that was not declared upfront' do
      expect {
        metrics.record(operation: :unknown, entity_class: 'Measure', count: 1, duration: 0)
      }.to raise_error(KeyError)
    end
  end
end
