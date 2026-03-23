RSpec.describe Reporting::Commodities do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    let(:serializer) { instance_double(Api::Admin::Csv::GoodsNomenclatureSerializer, serialized_csv: "sid\n1000000000\n") }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(described_class).to receive(:goods_nomenclatures).and_return([instance_double(Chapter)])
      allow(Api::Admin::Csv::GoodsNomenclatureSerializer).to receive(:new).and_return(serializer)
    end

    it 'writes a CSV file to the reporting bucket' do
      described_class.generate

      expect(s3_bucket.client.api_requests).to include(
        hash_including(
          operation_name: :put_object,
          params: hash_including(
            bucket: s3_bucket.name,
            key: /^.*\/commodities_.*\.csv$/,
            body: "sid\n1000000000\n",
            content_type: 'text/csv',
          ),
        ),
      )
    end
  end
end
