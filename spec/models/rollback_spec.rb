RSpec.describe Rollback do
  describe 'validations' do
    context 'with correct info' do
      let(:rollback) { build :rollback }

      it 'is a valid entity' do
        expect(rollback).to be_valid
      end
    end

    context 'with incorrect date provided' do
      let(:rollback) { build :rollback, date: 'abc' }

      it 'is not a valid entity' do
        expect(rollback).not_to be_valid
      end
    end
  end

  describe 'creating' do
    it 'does not enqueue a worker (the controller does that)' do
      allow(RollbackWorker).to receive(:perform_async)

      create :rollback

      expect(RollbackWorker).not_to have_received(:perform_async)
    end

    it 'does not default whodunnit from the current request' do
      TradeTariffRequest.whodunnit = 'request-user'

      expect(build(:rollback, whodunnit: nil)).not_to be_valid
    ensure
      TradeTariffRequest.reset
    end
  end
end
