RSpec.describe SynchronizerCheckWorker, type: :worker do
  describe '#perform' do
    before { allow(::Sentry).to receive(:capture_message) }

    context 'with data' do
      before do
        QuotaBalanceEvent::Operation.where(oid: qbe.oid).update(created_at:)

        described_class.new.perform
      end

      let(:qbe) { create :quota_balance_event }

      context 'when it is up to date' do
        let(:created_at) { 1.day.ago }

        it 'takes no action' do
          expect(Sentry).not_to have_received(:capture_message)
        end
      end

      context 'when it is outdated' do
        let(:created_at) { 10.days.ago }

        it 'alerts with the failing service' do
          expect(Sentry).to have_received(:capture_message).with %r{CDS sync problem}
        end
      end
    end

    context 'with no data' do
      before { described_class.new.perform }

      it 'alerts with the failing service' do
        expect(Sentry).to have_received(:capture_message).with %r{CDS sync problem}
      end
    end
  end
end
