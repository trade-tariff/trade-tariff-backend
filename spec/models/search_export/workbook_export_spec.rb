RSpec.describe SearchExport::WorkbookExport do
  subject(:export) { described_class.create(from_date: Date.yesterday, to_date: Date.current) }

  include_context 'with workbook exports'

  let(:result) { SearchExport::Workbook::Result.new(bytes: "PK\xFF".b, row_count: 2, omitted_count: 1) }

  it 'stores dates and status with fixed one-hour expiry' do
    expect(export.payload).to include('status' => 'queued', 'from' => Date.yesterday.iso8601, 'to' => Date.current.iso8601)
    expect(Sidekiq.redis { |redis| redis.ttl(export.key) }).to be_between(1, 3600)
  end

  it 'claims only once across concurrent workers' do
    id = export.id
    claims = Array.new(5) { Thread.new { described_class.new(id).claim } }.map(&:value)
    expect(claims.count(true)).to eq(1)
  end

  it 'stores binary bytes separately from status without extending expiry' do
    Sidekiq.redis { |redis| redis.expire(export.key, 60) }
    export.claim
    expect(export.finish(result)).to be(true)
    expect(export.payload).to include('status' => 'ready', 'row_count' => 2, 'omitted_count' => 1)
    expect(export.payload).not_to have_key('file')
    expect(export.file.b).to eq(result.bytes)
    expect(Sidekiq.redis { |redis| redis.ttl(export.file_key) }).to be_between(1, 60)
  end

  it 'does not replace terminal state or recreate expired files' do
    export.claim
    export.fail('Failed')
    expect(export.finish(result)).to be(false)
    expect(export.file).to be_nil
    export.delete
    expect(export.finish(result)).to be(false)
    expect(export.payload).to be_nil
    expect(export.file).to be_nil
  end

  it 'aborts completion when another worker changes the status during the transaction' do
    export.claim
    Sidekiq.redis do |redis|
      allow(redis).to receive(:multi).and_wrap_original do |method, **options, &block|
        method.call(**options) do |transaction|
          block.call(transaction)
          Thread.new { described_class.new(export.id).fail('Timed out') }.value
        end
      end
      expect(export.finish(result)).to be(false)
    end
    expect(export.payload).to include('status' => 'failed', 'error' => 'Timed out')
    expect(export.file).to be_nil
  end

  it 'aborts completion if the watched status expires before the transaction commits' do
    export.claim
    Sidekiq.redis do |redis|
      allow(redis).to receive(:multi).and_wrap_original do |method, **options, &block|
        method.call(**options) do |transaction|
          block.call(transaction)
          Thread.new { Sidekiq.redis { |other| other.del(export.key) } }.value
        end
      end
      expect(export.finish(result)).to be(false)
    end
    expect(export.payload).to be_nil
    expect(export.file).to be_nil
  end

  it 'fails stale pending jobs and refuses a late completion' do
    export.claim
    travel 16.minutes do
      export.expire_if_stale!
      expect(export.payload['status']).to eq('failed')
      expect(export.finish(result)).to be(false)
    end
  end

  it 'rejects files above the per-export size bound' do
    stub_const('SearchExport::WorkbookExport::MAX_FILE_BYTES', 1)
    export.claim
    expect { export.finish(result) }.to raise_error(described_class::TooLarge)
    expect(export.file).to be_nil
  end

  it 'bounds retained exports including ready files and frees deleted slots' do
    export.claim
    export.finish(result)
    2.times { described_class.create(from_date: Date.yesterday, to_date: Date.current) }
    expect { described_class.create(from_date: Date.yesterday, to_date: Date.current) }.to raise_error(described_class::Busy)
    export.delete
    expect { described_class.create(from_date: Date.yesterday, to_date: Date.current) }.not_to raise_error
  end

  it 'keeps services separate' do
    id = export.id
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    expect(described_class.find(id)).to be_nil
  ensure
    allow(TradeTariffBackend).to receive(:service).and_call_original
  end
end
