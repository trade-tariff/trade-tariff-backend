RSpec.shared_examples 'an oplog batch record inserter' do
  let(:duplicate_key_message) { 'PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "measures_pkey"' }

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
    allow(operation_klass).to receive(:multi_insert).and_raise(Sequel::UniqueConstraintViolation, duplicate_key_message)
    inserter.process_record(entity)

    expect { inserter.after_parse }.to raise_error(Sequel::UniqueConstraintViolation, duplicate_key_message)
  end

  it 'logs the failed batch element ids before raising' do
    allow(Rails.logger).to receive(:error)
    allow(operation_klass).to receive(:multi_insert).and_raise(Sequel::UniqueConstraintViolation, duplicate_key_message)
    inserter.process_record(entity)

    expect { inserter.after_parse }.to raise_error(Sequel::UniqueConstraintViolation, duplicate_key_message)

    expect(Rails.logger).to have_received(:error).with(a_string_including(entity.element_id))
  end

  it 'still raises an error when only the final, after_parse-flushed batch fails' do
    inserter.process_record(entity)
    inserter.process_record(entity)

    expect(operation_klass).to have_received(:multi_insert).once

    allow(operation_klass).to receive(:multi_insert).and_raise(Sequel::UniqueConstraintViolation, duplicate_key_message)
    inserter.process_record(entity)

    expect { inserter.after_parse }.to raise_error(Sequel::UniqueConstraintViolation, duplicate_key_message)
  end
end
