RSpec.describe TradeTariffBackend do
  describe '.reindex_all' do
    let(:indexer) { double }

    context 'when successful' do
      before do
        allow(indexer).to receive(:update_all).and_return(true)

        described_class.reindex(indexer)
      end

      it { expect(indexer).to have_received(:update_all) }
    end

    context 'when failed' do
      before do
        allow(indexer).to receive(:update_all).and_raise(StandardError)

        described_class.reindex(indexer)
      end

      it { expect(ActionMailer::Base.deliveries.last.encoded).to match(/failed to reindex/) }
    end
  end

  describe '.sidekiq_redis_config' do
    after { described_class.instance_variable_set(:@redis, nil) }

    context 'when SIDEKIQ_REDIS_URL is set' do
      before { stub_const('ENV', ENV.to_hash.merge('SIDEKIQ_REDIS_URL' => 'redis://sidekiq-host:6379')) }

      it 'returns the SIDEKIQ_REDIS_URL' do
        expect(described_class.sidekiq_redis_config[:url]).to eq('redis://sidekiq-host:6379')
      end
    end

    context 'when SIDEKIQ_REDIS_URL is not set' do
      before { stub_const('ENV', ENV.to_hash.except('SIDEKIQ_REDIS_URL').merge('REDIS_URL' => 'redis://default-host:6379')) }

      it 'falls back to REDIS_URL' do
        expect(described_class.sidekiq_redis_config[:url]).to eq('redis://default-host:6379')
      end
    end
  end

  describe '.currency' do
    before do
      allow(described_class).to receive(:service).and_return(choice)
    end

    context 'when the service is xi' do
      let(:choice) { 'xi' }

      it 'returns the correct currency' do
        expect(described_class.currency).to eq('EUR')
      end
    end

    context 'when the service is uk' do
      let(:choice) { 'uk' }

      it 'returns the correct currency' do
        expect(described_class.currency).to eq('GBP')
      end
    end

    context 'when the service is not set' do
      let(:choice) { nil }

      it 'returns the correct currency' do
        expect(described_class.currency).to eq('GBP')
      end
    end
  end

  describe '#revision' do
    subject { described_class.revision }

    before do
      described_class.instance_variable_set(:@revision, nil)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:file?).and_call_original
    end

    after { described_class.instance_variable_set(:@revision, nil) }

    context 'with revision file' do
      before do
        allow(File).to receive(:file?).with(described_class::REVISION_FILE)
                                      .and_return true

        allow(File).to receive(:read).with(described_class::REVISION_FILE)
                                     .and_return "ABCDEF01\n"
      end

      it { is_expected.to eql 'ABCDEF01' }
    end

    context 'with unreadable revision file' do
      before do
        allow(File).to receive(:file?).with(described_class::REVISION_FILE)
                                      .and_return true

        allow(File).to receive(:read).with(described_class::REVISION_FILE)
                                     .and_raise Errno::EACCES
      end

      it { is_expected.to be_nil }
    end

    context 'without revision file' do
      before do
        allow(File).to receive(:file?).with(described_class::REVISION_FILE)
                                      .and_return false
      end

      it { is_expected.to be_nil }
    end
  end
end
