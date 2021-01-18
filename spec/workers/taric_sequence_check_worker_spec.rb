require 'rails_helper'

describe TaricSequenceCheckWorker, type: :worker do
  before do
    allow($stdout).to receive(:write)
    allow_any_instance_of(TariffSynchronizer::TaricSequenceChecker).to receive(:perform)
  end

  describe '#perfomr' do
    it 'creates an instance of TaricSequenceCheck' do
      expect(TariffSynchronizer::TaricSequenceChecker).to receive(:new).with(true).and_call_original

      described_class.new.perform
    end

    it 'calls perform for the instance of TaricSequenceCheck' do
      expect_any_instance_of(TariffSynchronizer::TaricSequenceChecker).to receive(:perform)

      described_class.new.perform
    end
  end
end
