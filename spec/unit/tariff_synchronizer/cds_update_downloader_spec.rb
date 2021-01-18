require 'rails_helper'
require 'tariff_synchronizer/tariff_downloader'

describe TariffSynchronizer::CdsUpdateDownloader do
  let(:example_date) { Date.new(2020, 10, 10) }
  let(:downloader) { described_class.new(example_date) }

  describe '#perform' do
    let(:body) do
      [{
        'filename' => 'tariff_dailyExtract_v1_20201010T235959.gzip',
        'downloadURL' => 'https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a041a',
        'fileSize' => 12_345,
      },
       {
         'filename' => 'tariff_dailyExtract_v1_20201005T235959.gzip',
         'downloadURL' => 'https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a042b',
         'fileSize' => 12_345,
       },
       {
         'filename' => 'tariff_dailyExtract_v1_20201004T235959.gzip',
         'downloadURL' => 'https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a043c',
         'fileSize' => 12_345,
       }]
    end

    before do
      allow(downloader).to receive(:response) { double('Response', body: body.to_json) }
      allow_any_instance_of(TariffSynchronizer::TariffDownloader).to receive(:perform)
    end

    it 'logs request to cds daily updates' do
      expect(downloader).to receive(:log_request_to_cds_daily_updates)
      downloader.perform
    end

    context 'when response contains example_date' do
      it 'calls TariffDownloader for requested date..5 days ago' do
        expect(TariffSynchronizer::TariffDownloader).to receive(:new).with(
          body[0]['filename'], body[0]['downloadURL'], example_date, TariffSynchronizer::CdsUpdate
        ).and_call_original
        expect(TariffSynchronizer::TariffDownloader).to receive(:new).with(
          body[1]['filename'], body[1]['downloadURL'], example_date - 5.days, TariffSynchronizer::CdsUpdate
        ).and_call_original
        expect(TariffSynchronizer::TariffDownloader).not_to receive(:new).with(
          body[2]['filename'], body[2]['downloadURL'], example_date - 6.days, TariffSynchronizer::CdsUpdate
        )
        downloader.perform
      end

      it 'does not create missing update record' do
        expect { downloader.perform }.not_to change(TariffSynchronizer::BaseUpdate.missing, :count)
      end
    end

    context 'when response is empty' do
      let(:body) { [] }

      it 'does not call TariffDownloader' do
        expect(TariffSynchronizer::TariffDownloader).not_to receive(:new)
        downloader.perform
      end

      it 'returns nil' do
        expect(downloader.perform).to be_nil
      end
    end
  end
end
