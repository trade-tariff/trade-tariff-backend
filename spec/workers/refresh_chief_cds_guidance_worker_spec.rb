RSpec.describe RefreshChiefCdsGuidanceWorker, type: :worker do
  let(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(TradeTariffBackend).to receive(:chief_cds_guidance=).and_call_original
      allow(TradeTariffBackend).to receive(:chief_cds_guidance).and_return(existing_guidance)
      allow(ChiefCdsGuidance).to receive(:load_latest).and_return(new_guidance)
      allow(GuidanceChangeNotificationService).to receive(:new).and_call_original
      allow(SlackNotifierService).to receive(:call).and_call_original
    end

    context 'when the latest guidance has changed' do
      let(:new_guidance) { ChiefCdsGuidance.new(guidance: { 'foo' => 'bar' }) }
      let(:existing_guidance) { ChiefCdsGuidance.new(guidance: { 'foo' => 'baz' }) }

      it 'refreshes the guidance' do
        worker.perform

        expect(TradeTariffBackend).to have_received(:chief_cds_guidance=).with(new_guidance)
      end

      it 'notifies slack' do
        worker.perform

        expect(GuidanceChangeNotificationService).to have_received(:new).with(
          new_guidance.guidance,
          existing_guidance.guidance,
        )
      end

      it 'updates the guidance_last_updated_at timestamp' do
        worker.perform

        expect(new_guidance.guidance_last_updated_at).to be_within(5.seconds).of(Time.zone.now)
      end
    end

    context 'when latest guidance has not changed' do
      let(:new_guidance) { ChiefCdsGuidance.new(guidance: { 'foo' => 'bar' }) }
      let(:existing_guidance) { ChiefCdsGuidance.new(guidance: { 'foo' => 'bar' }) }

      it 'does not refresh the guidance' do
        worker.perform

        expect(TradeTariffBackend).not_to have_received(:chief_cds_guidance=)
      end

      it 'does not notify slack' do
        worker.perform

        expect(GuidanceChangeNotificationService).not_to have_received(:new)
      end
    end

    context 'when neither the latest guidance nor the existing guidance are present' do
      let(:new_guidance) { nil }
      let(:existing_guidance) { nil }
      let(:fallback_guidance) { TradeTariffBackend.chief_cds_guidance }

      it 'does not notify slack of changes' do
        worker.perform

        expect(GuidanceChangeNotificationService).not_to have_received(:new)
      end

      it 'notifies slack that we are using a fallback' do
        worker.perform

        expect(SlackNotifierService).to have_received(:call)
      end
    end
  end
end
