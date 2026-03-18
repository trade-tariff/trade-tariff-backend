RSpec.describe DataExportWorker, type: :worker do
  subject(:perform_worker) { described_class.new.perform(data_export.id) }

  let(:subscription) { create(:user_subscription, subscription_type: Subscriptions::Type.my_commodities) }
  let(:data_export) { create(:data_export, user_subscription: subscription) }

  let(:exporter) { instance_double(Api::User::ActiveCommoditiesService) }

  let(:storage_service) { instance_double(Api::User::DataExportService::StorageService) }

  let(:result) do
    {
      file_name: 'mock-file.xlsx',
      content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      body: 'mock excel data',
    }
  end

  let(:expected_key) do
    "data/export/#{Time.zone.today.strftime('%Y')}/#{Time.zone.today.strftime('%m')}/#{Time.zone.today.strftime('%d')}/#{data_export.export_type}/#{data_export.id}_#{result[:file_name]}"
  end

  before do
    allow(PublicUsers::DataExport).to receive(:[]).with(data_export.id).and_return(data_export)
    allow(data_export).to receive_messages(user_subscription: subscription, exporter_class: 'Api::User::ActiveCommoditiesService')
    allow(Api::User::ActiveCommoditiesService).to receive(:new).with(subscription).and_return(exporter)
    allow(exporter).to receive(:download_payload).and_return(result)

    allow(Api::User::DataExportService::StorageService).to receive(:new).and_return(storage_service)
    allow(storage_service).to receive(:upload)
  end

  describe '#perform' do
    it 'uploads to storage and marks export completed' do
      perform_worker

      expect(storage_service).to have_received(:upload).with(
        key: expected_key,
        body: result[:body],
        content_type: result[:content_type],
      )

      expect(data_export.reload.status).to eq(PublicUsers::DataExport::COMPLETED)
      expect(data_export.reload.s3_key).to eq(expected_key)
      expect(data_export.reload.file_name).to eq(result[:file_name])
    end

    context 'when export generation errors' do
      before do
        allow(Sidekiq.logger).to receive(:error)
        allow(exporter).to receive(:download_payload).and_raise(StandardError, 'boom')
      end

      it 'marks export failed and re-raises' do
        expect { perform_worker }.to raise_error(StandardError, 'boom')
        expect(data_export.reload.status).to eq(PublicUsers::DataExport::FAILED)
      end
    end
  end
end
