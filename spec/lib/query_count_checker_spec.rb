RSpec.describe QueryCountChecker do
  subject(:check_count) { described_class.new(threshold).check }

  before { allow(NewRelic::Agent).to receive(:notice_error).and_return true }

  let(:threshold) { 20 }

  context 'with request count under threshold' do
    before do
      allow(::SequelRails::Railties::LogSubscriber).to receive(:count).and_return threshold
    end

    it 'does not raise an exception' do
      expect { check_count }.not_to raise_exception
    end

    it 'does not notify New Relic' do
      check_count

      expect(NewRelic::Agent).not_to have_received :notice_error
    end
  end

  context 'with request count over threshold' do
    before do
      allow(::SequelRails::Railties::LogSubscriber).to receive(:count).and_return threshold + 1
    end

    context 'with exceptions mode' do
      it 'raises an exception' do
        expect { check_count }.to raise_exception \
          described_class::ExcessQueryCountException, /excess queries detected/i
      end

      it 'does not notify new relic' do
        check_count
      rescue described_class::ExcessQueryCountException
        expect(NewRelic::Agent).not_to have_received :notice_error
      end
    end

    context 'with alerting mode' do
      subject(:check_count) { described_class.new(threshold, raise_exception: false).check }

      it 'does not raise an exception' do
        expect(check_count).to be false
      end

      it 'notifies new relic' do
        check_count

        expect(NewRelic::Agent).to have_received(:notice_error).with \
          "Excess queries detected: #{threshold + 1} (limit: #{threshold})"
      end
    end
  end
end
