RSpec.describe Api::User::DataExportService::SubscriptionTargetsDownloadService do
  let(:subscription) { create(:user_subscription, subscription_type: Subscriptions::Type.my_commodities) }
  let(:service) { described_class.new(subscription) }

  let(:package) { instance_double(Axlsx::Package) }
  let(:stream) { StringIO.new('mock excel data') }
  let(:active_commodities_service) { instance_double(Api::User::ActiveCommoditiesService) }

  let(:result) do
    {
      file_name: "commodity_watch_list-your_codes_#{Time.zone.now.strftime('%Y-%m-%d')}.xlsx",
      content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      body: 'mock excel data',
    }
  end

  before do
    allow(Api::User::ActiveCommoditiesService).to receive(:new).with(subscription).and_return(active_commodities_service)
    allow(active_commodities_service).to receive(:generate_report).and_return(package)
    allow(package).to receive(:to_stream).and_return(stream)
  end

  describe '#call' do
    it 'returns an Excel file with expected headers and body' do
      freeze_time do
        expect(service.call).to eq(result)
      end
    end
  end
end
