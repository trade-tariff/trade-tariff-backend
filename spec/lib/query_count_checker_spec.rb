require 'rails_helper'

RSpec.describe QueryCountChecker do
  subject(:check_count) { described_class.new(threshold).check }

  before { allow(Sentry).to receive(:capture_message).and_return true }

  let(:threshold) { 20 }

  context 'with request count under threshold' do
    before do
      allow(::SequelRails::Railties::LogSubscriber).to receive(:count).and_return threshold
    end

    it 'does not raise an exception' do
      expect { check_count }.not_to raise_exception
    end

    it 'does not notify sentry' do
      check_count

      expect(Sentry).not_to have_received :capture_message
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

      it 'does not notify sentry' do
        check_count
      rescue described_class::ExcessQueryCountException
        expect(Sentry).not_to have_received :capture_message
      end
    end

    context 'with alerting mode' do
      subject(:check_count) { described_class.new(threshold, raise_exception: false).check }

      it 'does not raise an exception' do
        expect(check_count).to be false
      end

      it 'notifies sentry' do
        check_count

        expect(Sentry).to have_received(:capture_message).with \
          "Excess queries detected: #{threshold + 1} (limit: #{threshold})"
      end
    end
  end
end
