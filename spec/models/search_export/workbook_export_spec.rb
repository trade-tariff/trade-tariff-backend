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

  it 'allows completion after fifteen minutes' do
    export.claim
    travel 16.minutes do
      expect(export.finish(result)).to be(true)
      expect(export.payload['status']).to eq('ready')
    end
  end

  it 'stores files larger than ten MiB' do
    large_result = result.with(bytes: 'x' * 11.megabytes)
    export.claim
    expect(export.finish(large_result)).to be(true)
    expect(export.file).to eq(large_result.bytes)
  end

  it 'creates exports without a retained-export quota' do
    export.claim
    export.finish(result)
    exports = Array.new(5) { |index| described_class.create(from_date: Date.yesterday - index, to_date: Date.current) }
    expect(exports.map { |entry| entry.payload['status'] }).to eq(Array.new(5, 'queued'))
    expect(export.payload['status']).to eq('ready')
  end

  it 'deduplicates concurrent submissions using the same fingerprint' do
    threads = Array.new(5) do
      Thread.new { described_class.create(from_date: Date.yesterday, to_date: Date.current) }
    end
    exports = threads.map(&:value)
    expect(exports.map(&:id).uniq.size).to eq(1)
    expect(exports.count(&:newly_created?)).to eq(1)
  end

  it 'reuses queued and running exports without extending their expiry' do
    original = export
    Sidekiq.redis { |redis| redis.expire(original.key, 60) }
    duplicate = described_class.create(from_date: Date.yesterday, to_date: Date.current)
    expect(duplicate.id).to eq(original.id)
    expect(duplicate.newly_created?).to be(false)
    original.claim
    expect(described_class.create(from_date: Date.yesterday, to_date: Date.current).id).to eq(original.id)
    expect(Sidekiq.redis { |redis| redis.ttl(original.key) }).to be_between(1, 60)
  end

  it 'allows another submission after completion, failure or expiry' do
    original = export
    original.claim
    original.finish(result)
    subsequent = described_class.create(from_date: Date.yesterday, to_date: Date.current)
    expect(subsequent.id).not_to eq(original.id)
    subsequent.claim
    subsequent.fail('Failed')
    retry_export = described_class.create(from_date: Date.yesterday, to_date: Date.current)
    expect(retry_export.id).not_to eq(subsequent.id)
    retry_export.delete
    replacement = described_class.create(from_date: Date.yesterday, to_date: Date.current)
    expect(replacement.id).not_to eq(retry_export.id)
    expect(replacement.newly_created?).to be(true)
  end

  it 'fingerprints both dates and the service' do
    original = export
    changed_from = described_class.create(from_date: Date.yesterday - 1, to_date: Date.current)
    changed_to = described_class.create(from_date: Date.yesterday, to_date: Date.current + 1)
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    other_service = described_class.create(from_date: Date.yesterday, to_date: Date.current)
    expect([original, changed_from, changed_to, other_service].map(&:id).uniq.size).to eq(4)
    other_service.delete
  ensure
    allow(TradeTariffBackend).to receive(:service).and_call_original
  end

  it 'keeps services separate' do
    id = export.id
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    expect(described_class.find(id)).to be_nil
  ensure
    allow(TradeTariffBackend).to receive(:service).and_call_original
  end
end
