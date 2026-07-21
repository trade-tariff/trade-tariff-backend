RSpec.shared_examples 'an oplog batch record inserter' do
  before do
    allow(TradeTariffBackend).to receive(batch_size_setting).and_return(2)
    allow(ActiveSupport::Notifications).to receive(:instrument) do |*_args, &block|
      block&.call
    end
  end

  it 'buffers records until the batch size is reached' do
    inserter.process_record(entity)

    expect(operation_klass).not_to have_received(:multi_insert)

    inserter.process_record(entity)

    expect(operation_klass).to have_received(:multi_insert).once
  end

  it 'flushes the final partial batch after parsing' do
    inserter.process_record(entity)

    expect(operation_klass).not_to have_received(:multi_insert)

    inserter.after_parse

    expect(operation_klass).to have_received(:multi_insert).once
  end

  it 'propagates insertion errors' do
    allow(operation_klass).to receive(:multi_insert).and_raise(StandardError, 'insert failed')
    inserter.process_record(entity)

    expect { inserter.after_parse }.to raise_error(StandardError, 'insert failed')
  end
end
