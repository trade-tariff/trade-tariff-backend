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
      context 'when no Sidekiq processes are registered' do
        before { allow(Sidekiq::ProcessSet).to receive(:new).and_return([]) }

        it { is_expected.to include sidekiq: false }
      end

      context 'when at least one Sidekiq process is registered' do
        before { allow(Sidekiq::ProcessSet).to receive(:new).and_return([instance_double(Sidekiq::Process)]) }

        it { is_expected.to include sidekiq: true }
      end
    end
  end

  describe '.check' do
    subject { described_class.check }

    before do
      allow(TradeTariffBackend).to receive(:revision).and_return nil
      allow(Sidekiq::ProcessSet).to receive(:new).and_return([instance_double(Sidekiq::Process)])
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
