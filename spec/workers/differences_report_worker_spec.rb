RSpec.describe DifferencesReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe 'sidekiq configuration' do
    it 'retries twice' do
      expect(described_class.get_sidekiq_options['retry']).to eq(2)
    end

    it 'waits an hour between retries so late report publications can appear' do
      expect(described_class.sidekiq_retry_in_block.call(0, nil)).to eq(1.hour.to_i)
    end
  end

  describe '#perform' do
    before do
      allow(Reporting::Differences).to receive(:generate).and_return(differences)
      allow(differences).to receive_messages(
        sections: [],
        as_of: report_date,
        workbook_data: 'xlsx-bytes',
        uk_commodities_link: 'https://example.test/uk-commodities',
        xi_commodities_link: 'https://example.test/xi-commodities',
        uk_supplementary_units_link: 'https://example.test/uk-supplementary-units',
        xi_supplementary_units_link: 'https://example.test/xi-supplementary-units',
      )
    end

    let(:report_date) { Time.zone.today.iso8601 }
    let(:differences) { Reporting::Differences.new }

    context 'when delivering email' do
      before { worker.perform }

      it { expect(Reporting::Differences).to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(1) }

      it 'serializes the workbook once and attaches those bytes' do
        expect(differences).to have_received(:workbook_data).once

        attachment = ActionMailer::Base.deliveries.last.attachments["differences_#{report_date}.xlsx"]
        expect(attachment.body.decoded).to eq('xlsx-bytes')
      end
    end

    context 'when not delivering email' do
      before { worker.perform(false) }

      it { expect(Reporting::Differences).to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(0) }
    end

    context 'when the report completes' do
      before { worker.perform(false) }

      it 'records a single completion marker for today' do
        expect(DifferencesLog.where(key: described_class::COMPLETION_KEY, date: Time.zone.today).count).to eq(1)
      end
    end

    context 'when the report is run twice in one day' do
      before do
        worker.perform(false)
        worker.perform(false)
      end

      it 'keeps exactly one completion marker for today' do
        expect(DifferencesLog.where(key: described_class::COMPLETION_KEY, date: Time.zone.today).count).to eq(1)
      end
    end

    context 'when the report raises part way through' do
      before do
        allow(Reporting::Differences).to receive(:generate).and_raise(StandardError, 'boom')
      end

      it 'does not record a completion marker' do
        expect { worker.perform(false) }.to raise_error(StandardError, 'boom')
        expect(DifferencesLog.where(key: described_class::COMPLETION_KEY)).to be_empty
      end
    end
  end
end
