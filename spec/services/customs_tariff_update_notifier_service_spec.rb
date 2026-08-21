RSpec.describe CustomsTariffUpdateNotifierService do
  subject(:service) { described_class.new(update.version) }

  let(:update) { create(:customs_tariff_update, validity_start_date: Date.new(2026, 2, 1)) }

  before do
    create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'note')
  end

  describe '#call' do
    context 'when no recipient is configured' do
      before { allow(TradeTariffBackend).to receive(:support_email).and_return('') }

      it 'fires send_skipped and does not attempt to enqueue anything' do
        allow(Notifications::Instrumentation).to receive(:send_skipped)
        allow(Notifications::EnqueueService).to receive(:new)

        service.call

        expect(Notifications::Instrumentation).to have_received(:send_skipped).with(
          pipeline: 'customs_tariff_update', identifier: update.version, reason: 'recipient_not_configured',
        )
        expect(Notifications::EnqueueService).not_to have_received(:new)
      end
    end

    context 'when the version does not correspond to any known update' do
      subject(:service) { described_class.new('unknown-version') }

      before { allow(TradeTariffBackend).to receive(:support_email).and_return('recipient@example.com') }

      it 'fires send_skipped with update_not_found and does not build a change summary or enqueue anything' do
        allow(Notifications::Instrumentation).to receive(:send_skipped)
        allow(CustomsTariffUpdateChangeSummary).to receive(:new)
        allow(Notifications::EnqueueService).to receive(:new)

        service.call

        expect(Notifications::Instrumentation).to have_received(:send_skipped).with(
          pipeline: 'customs_tariff_update', identifier: 'unknown-version', reason: 'update_not_found',
        )
        expect(CustomsTariffUpdateChangeSummary).not_to have_received(:new)
        expect(Notifications::EnqueueService).not_to have_received(:new)
      end
    end

    context 'when a recipient is configured' do
      before { allow(TradeTariffBackend).to receive(:support_email).and_return('recipient@example.com') }

      it 'enqueues Notifications::EmailWorker via Notifications::EnqueueService with the built personalisation' do
        allow(Notifications::EmailWorker).to receive(:perform_async)

        service.call

        expect(Notifications::EmailWorker).to have_received(:perform_async).with(
          'recipient@example.com',
          described_class::TEMPLATE_ID,
          hash_including(
            'version' => update.version,
            'document_created_on' => update.document_created_on.iso8601,
            'document_url' => update.source_url,
            'imported_on' => update.created_at.iso8601,
            'entry_into_force_on' => update.validity_start_date.iso8601,
            'chapter_ids' => '01',
            'section_ids' => '',
          ),
          'CustomsTariffUpdateNotificationStatusCheckWorker',
          [update.version],
        )
      end

      it 'builds a String-keyed personalisation hash and enqueues via the real Sidekiq perform_async boundary without raising' do
        Sidekiq::Testing.fake! do
          Notifications::EmailWorker.jobs.clear

          expect { service.call }.not_to raise_error

          expect(Notifications::EmailWorker.jobs.size).to eq(1)
          args = Notifications::EmailWorker.jobs.first['args']
          personalisation = args[2]

          expect(personalisation.keys).to all(be_a(String))
          expect(personalisation).to include(
            'version' => update.version,
            'chapter_ids' => '01',
          )
        end
      end

      it 'falls back to a placeholder string when document_created_on is nil, rather than sending a null personalisation value' do
        update.update(document_created_on: nil)
        allow(Notifications::EmailWorker).to receive(:perform_async)

        service.call

        expect(Notifications::EmailWorker).to have_received(:perform_async).with(
          anything, anything, hash_including('document_created_on' => 'Not available'), anything, anything
        )
      end

      it 'falls back to a placeholder string when source_url is blank, rather than sending an empty personalisation value' do
        update.update(source_url: nil)
        allow(Notifications::EmailWorker).to receive(:perform_async)

        service.call

        expect(Notifications::EmailWorker).to have_received(:perform_async).with(
          anything, anything, hash_including('document_url' => 'Not available'), anything, anything
        )
      end

      it 'labels the document as UK Customs Tariff when running in the UK service' do
        allow(TradeTariffBackend).to receive(:uk?).and_return(true)
        allow(Notifications::EmailWorker).to receive(:perform_async)

        service.call

        expect(Notifications::EmailWorker).to have_received(:perform_async).with(
          anything, anything, hash_including('document_type' => 'UK Customs Tariff'), anything, anything
        )
      end

      it 'labels the document as XI Combined Nomenclature when running in the XI service' do
        allow(TradeTariffBackend).to receive(:uk?).and_return(false)
        allow(Notifications::EmailWorker).to receive(:perform_async)

        service.call

        expect(Notifications::EmailWorker).to have_received(:perform_async).with(
          anything, anything, hash_including('document_type' => 'XI Combined Nomenclature'), anything, anything
        )
      end
    end
  end

  describe 'the status-check worker class string used to schedule delivery checks' do
    it 'constantizes to the real CustomsTariffUpdateNotificationStatusCheckWorker class, which supports perform_in' do
      constantized = 'CustomsTariffUpdateNotificationStatusCheckWorker'.constantize

      expect(constantized).to eq(CustomsTariffUpdateNotificationStatusCheckWorker)
      expect(constantized).to respond_to(:perform_in)
    end
  end
end
