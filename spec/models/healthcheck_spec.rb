RSpec.describe Healthcheck do
  subject(:instance) { described_class.instance }

  describe '#current_revision' do
    subject { instance.current_revision }

    before do
      instance.instance_variable_set(:@current_revision, nil)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:file?).and_call_original
    end

    after { instance.instance_variable_set(:@current_revision, nil) }

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

      it { is_expected.to eql 'test' }
    end

    context 'without revision file' do
      it { is_expected.to eql 'test' }
    end
  end

  describe '#check' do
    subject(:check) { instance.check }

    before { allow(Section).to receive(:all).and_return [] }

    it { is_expected.to include git_sha1: 'test' }

    it 'tests postgres' do
      check

      expect(Section).to have_received(:all)
    end

    context 'with broken db connection' do
      before { allow(Section).to receive(:all).and_raise Sequel::DatabaseDisconnectError }

      it { expect { check }.to raise_exception Sequel::DatabaseDisconnectError }
    end

    describe 'sidekiq health' do
      before do
        allow(Rails.cache).to receive(:read).and_call_original
        allow(Rails.cache).to receive(:read).with(described_class::SIDEKIQ_KEY)
                                            .and_return(health_key)
      end

      context 'with no cache key' do
        let(:health_key) { nil }

        it { is_expected.to include sidekiq: false }
      end

      context 'with recent cache key' do
        let :health_key do
          (described_class::SIDEKIQ_THRESHOLD - 1.minute).ago.utc.iso8601
        end

        it { is_expected.to include sidekiq: true }
      end

      context 'with outdated cache key' do
        let :health_key do
          (described_class::SIDEKIQ_THRESHOLD + 1.minute).ago.utc.iso8601
        end

        it { is_expected.to include sidekiq: false }
      end
    end
  end

  describe '.check' do
    subject { described_class.check }

    it { is_expected.to include sidekiq: false }
  end
end
