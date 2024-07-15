RSpec.describe Healthcheck do
  subject(:instance) { described_class.instance }

  before do
    allow(TradeTariffBackend).to receive(:revision).and_return nil
  end

  describe '#current_revision' do
    subject { instance.current_revision }

    context 'with revision file' do
      before { allow(TradeTariffBackend).to receive(:revision).and_return 'ABCDEF01' }

      it { is_expected.to eql 'ABCDEF01' }
    end

    context 'without revision file' do
      it { is_expected.to eql 'test' }
    end
  end

  describe '#check' do
    subject(:check) { instance.check }

    context 'with broken db connection' do
      before do
        allow(Sequel::Model.db).to receive(:test_connection).and_return(false)
      end

      it { expect(check).to include postgres: false }
    end

    describe 'sidekiq health' do
      context 'with no cache key' do
        before { TradeTariffBackend.redis.del described_class::SIDEKIQ_KEY }

        it { is_expected.to include sidekiq: false }
      end

      context 'with recent cache key' do
        before do
          TradeTariffBackend.redis.set \
            described_class::SIDEKIQ_KEY,
            (described_class::SIDEKIQ_THRESHOLD - 1.minute).ago.utc.iso8601
        end

        it { is_expected.to include sidekiq: true }
      end

      context 'with outdated cache key' do
        before do
          TradeTariffBackend.redis.set \
            described_class::SIDEKIQ_KEY,
            (described_class::SIDEKIQ_THRESHOLD + 1.minute).ago.utc.iso8601
        end

        it { is_expected.to include sidekiq: false }
      end
    end
  end

  describe '.check' do
    subject { described_class.check }

    before do
      allow(TradeTariffBackend).to receive(:revision).and_return nil

      TradeTariffBackend.redis.set \
        described_class::SIDEKIQ_KEY,
        (described_class::SIDEKIQ_THRESHOLD - 1.minute).ago.utc.iso8601
    end

    let(:expected) do
      {
        git_sha1: 'test',
        healthy: true,
        opensearch: true,
        postgres: true,
        redis: true,
        sidekiq: true,
      }
    end

    it { is_expected.to eql expected }
  end
end
