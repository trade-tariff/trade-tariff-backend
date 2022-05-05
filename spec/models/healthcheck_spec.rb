RSpec.describe Healthcheck do
  describe '.current_revision' do
    subject { described_class.current_revision }

    before do
      described_class.instance_variable_set(:@current_revision, nil)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:file?).and_call_original
    end

    after { described_class.instance_variable_set(:@current_revision, nil) }

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
    subject(:check) { described_class.new.check }

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
  end
end
