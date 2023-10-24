RSpec.shared_examples_for 'Base Update' do
  describe '.sync' do
    include BankHolidaysHelper

    before do
      stub_holidays_gem_between_call
    end

    context 'when last update is out of date' do
      it 'should_receive download to be invoked' do
        allow(described_class).to receive(:download)

        described_class.sync(initial_date: Time.zone.yesterday)

        expect(described_class).to have_received(:download).at_least(1)
      end
    end
  end

  describe '.update_type' do
    it 'raises error on base class' do
      expect { TariffSynchronizer::BaseUpdate.update_type }.to raise_error(RuntimeError)
    end

    it 'does not raise error on class that overrides it' do
      expect { described_class.update_type }.not_to raise_error
    end
  end
end
