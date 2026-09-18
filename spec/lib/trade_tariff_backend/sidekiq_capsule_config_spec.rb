# frozen_string_literal: true

RSpec.describe TradeTariffBackend::SidekiqCapsuleConfig do
  subject(:capsule_config) { described_class.new(env) }

  let(:env) { {} }

  describe '#capsules' do
    subject(:capsules) { capsule_config.capsules }

    it 'reserves disjoint queues' do
      expect(capsules.map(&:queues)).to eq(
        [
          %w[default within_1_hour],
          %w[sync],
          %w[within_1_day],
        ],
      )
    end

    it 'keeps the default total thread budget' do
      expect(capsules.map(&:concurrency)).to eq([4, 3, 3])
    end

    context 'with an explicit thread budget' do
      let(:env) do
        {
          'SIDEKIQ_CONCURRENCY' => '12',
          'SIDEKIQ_SYNC_CONCURRENCY' => '2',
          'SIDEKIQ_WITHIN_1_DAY_CONCURRENCY' => '5',
        }
      end

      it 'gives the remainder to default' do
        expect(capsules.map { |capsule| [capsule.name, capsule.concurrency] }).to eq(
          [
            ['default', 5],
            ['sync', 2],
            ['within_1_day', 5],
          ],
        )
      end
    end

    context 'when reserved capsules exhaust the budget' do
      let(:env) do
        {
          'SIDEKIQ_CONCURRENCY' => '5',
          'SIDEKIQ_SYNC_CONCURRENCY' => '3',
          'SIDEKIQ_WITHIN_1_DAY_CONCURRENCY' => '3',
        }
      end

      it 'raises an argument error' do
        expect { capsules }.to raise_error(ArgumentError, /at least 1 thread for default/)
      end
    end

    context 'with a non-positive reserved size' do
      let(:env) { { 'SIDEKIQ_SYNC_CONCURRENCY' => '0' } }

      it 'raises an argument error' do
        expect { capsules }.to raise_error(ArgumentError, /SIDEKIQ_SYNC_CONCURRENCY must be at least 1/)
      end
    end
  end

  describe '#apply!' do
    subject(:applied) { capsule_config.apply!(config) }

    let(:config) { Sidekiq::Config.new }

    it 'registers three capsules on the Sidekiq config' do
      expect(applied.capsules.keys).to contain_exactly('default', 'sync', 'within_1_day')
    end

    it 'keeps total concurrency at the thread budget' do
      expect(applied.total_concurrency).to eq(10)
    end

    it 'stops the default capsule fetching sync jobs' do
      expect(applied.capsules.fetch('default').queues).to eq(%w[default within_1_hour])
    end

    it 'gives sync its own fetcher' do
      sync = applied.capsules.fetch('sync')

      expect([sync.concurrency, sync.queues]).to eq([3, %w[sync]])
    end
  end
end
