RSpec.describe TaricImporter::RecordInserter do
  subject(:inserter) { described_class.new('2013-08-02_TGB13214.xml') }

  let(:batch_size_setting) { :taric_importer_batch_size }
  let(:operation_klass) do
    class_double(
      Measure::Operation,
      columns: %i[operation filename],
      multi_insert: nil,
    )
  end
  let(:mapper) do
    instance_double(
      TaricImporter::EntityMapper,
      entity_class: 'Measure',
    )
  end
  let(:instance) do
    double(
      class: double(operation_klass:),
      operation: :create,
      values: { operation: 'C', filename: nil },
    )
  end
  let(:entity) do
    TaricImporter::TaricEntity.new(
      element_id: '1:1',
      key: 'measure',
      instance:,
      mapper:,
    )
  end

  it_behaves_like 'an oplog batch record inserter'

  describe 'TARIC-specific behaviour' do
    before do
      allow(TradeTariffBackend).to receive(:taric_importer_batch_size).and_return(100)
      allow(ActiveSupport::Notifications).to receive(:instrument) do |*_args, &block|
        block&.call
      end
    end

    it 'emits the payload expected by the TARIC operation subscriber' do
      inserter.process_record(entity)
      inserter.after_parse
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        'taric_importer.import.operations',
        {
          mapper:,
          operation: :create,
          count: 1,
        },
      )
    end

    it 'preserves mixed operation order and does not add a filename' do
      entities = [
        entity_for(:create, 'C'),
        entity_for(:update, 'U'),
        entity_for(:destroy, 'D'),
      ]

      entities.each { |mapped_entity| inserter.process_record(mapped_entity) }
      inserter.after_parse
      expect(operation_klass).to have_received(:multi_insert)
                                   .with([{ operation: 'C', filename: nil }]).ordered
      expect(operation_klass).to have_received(:multi_insert)
                                   .with([{ operation: 'U', filename: nil }]).ordered
      expect(operation_klass).to have_received(:multi_insert)
                                   .with([{ operation: 'D', filename: nil }]).ordered
    end
  end

  def entity_for(operation, persisted_operation)
    mapped_instance = double(
      class: double(operation_klass:),
      operation:,
      values: { operation: persisted_operation, filename: nil },
    )

    TaricImporter::TaricEntity.new(
      element_id: "1:#{persisted_operation}",
      key: 'measure',
      instance: mapped_instance,
      mapper:,
    )
  end
end
