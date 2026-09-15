RSpec.describe SearchAnalyticsQueryResult do
  let(:attributes) do
    { service: 'uk',
      reporting_date: Date.new(2026, 9, 14),
      name: 'volume',
      fingerprint: 'definition-v1',
      rows: Sequel.pg_jsonb([{ 'searches' => 10 }]),
      collected_at: Time.current }
  end

  it 'stores a query result for one completed day' do
    result = described_class.create(attributes).refresh

    expect(result.rows.to_a).to eq([{ 'searches' => 10 }])
    expect(result.reporting_date).to eq(Date.new(2026, 9, 14))
    expect(result.fingerprint).to eq('definition-v1')
  end

  it 'stores a completed empty result rather than treating it as missing' do
    result = described_class.create(attributes.merge(rows: Sequel.pg_jsonb([])))

    expect(result.refresh.rows.to_a).to eq([])
  end

  it 'keeps query slots unique within a service and day' do
    described_class.create(attributes)

    expect { described_class.create(attributes.merge(fingerprint: 'definition-v2')) }
      .to raise_error(Sequel::UniqueConstraintViolation)
  end

  it 'allows the same query on another day or service and another query on the same day' do
    described_class.create(attributes)
    described_class.create(attributes.merge(service: 'xi'))
    described_class.create(attributes.merge(reporting_date: Date.new(2026, 9, 13)))
    described_class.create(attributes.merge(name: 'latency'))

    expect(described_class.count).to eq(4)
  end

  it 'replaces a stale query result without creating an attempt history' do
    result = described_class.create(attributes)
    replacement = attributes.merge(fingerprint: 'definition-v2', rows: Sequel.pg_jsonb([{ 'searches' => 20 }]))
    described_class.dataset.insert_conflict(target: %i[service reporting_date name], update: replacement).insert(replacement)

    expect(described_class.count).to eq(1)
    expect(result.refresh.fingerprint).to eq('definition-v2')
    expect(result.rows.to_a).to eq([{ 'searches' => 20 }])
  end

  describe '.fetch' do
    let(:identity) { attributes.slice(:service, :reporting_date, :name, :fingerprint) }

    it 'reuses matching successful results without executing again' do
      expect(described_class.fetch(**identity) { [] }).to eq([])
      expect(described_class.fetch(**identity) { raise 'must not execute' }).to eq([])
    end

    it 'reruns a changed definition and replaces only that query' do
      described_class.fetch(**identity) { [{ 'count' => 1 }] }
      rows = described_class.fetch(**identity.merge(fingerprint: 'changed')) { [{ 'count' => 2 }] }

      expect(rows).to eq([{ 'count' => 2 }])
      expect(described_class.count).to eq(1)
      expect(described_class.first.fingerprint).to eq('changed')
    end

    it 'reruns an explicitly forced query' do
      described_class.fetch(**identity) { [] }
      expect(described_class.fetch(**identity, force: true) { [{ 'count' => 3 }] }).to eq([{ 'count' => 3 }])
    end

    it 'reuses completed queries when another query fails and is retried' do
      described_class.fetch(**identity) { [{ 'count' => 1 }] }
      failed = identity.merge(name: 'latency')
      expect { described_class.fetch(**failed) { raise 'query failed' } }.to raise_error('query failed')
      expect(described_class.fetch(**identity) { raise 'must not execute' }).to eq([{ 'count' => 1 }])
      expect(described_class.fetch(**failed) { [] }).to eq([])
      expect(described_class.count).to eq(2)
    end

    it 'does not overwrite a previous result when a refresh fails' do
      described_class.fetch(**identity) { [{ 'count' => 1 }] }
      expect { described_class.fetch(**identity, force: true) { raise 'query failed' } }.to raise_error('query failed')
      expect(described_class.first.rows.to_a).to eq([{ 'count' => 1 }])
    end

    it 'does not store a missing or invalid query result' do
      expect { described_class.fetch(**identity) { nil } }.to raise_error(ArgumentError, /array/) # rubocop:disable Style/RedundantFetchBlock
      expect(described_class.count).to eq(0)
    end
  end

  it 'can remove results that need to be recollected' do
    result = described_class.create(attributes)
    described_class.where(id: result.id).delete

    expect(described_class.count).to eq(0)
  end
end
