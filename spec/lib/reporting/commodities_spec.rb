RSpec.describe Reporting::Commodities do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    let(:serializer) { instance_double(Api::Admin::Csv::GoodsNomenclatureSerializer) }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(described_class).to receive(:goods_nomenclatures).and_return([instance_double(Chapter)])
      allow(Api::Admin::Csv::GoodsNomenclatureSerializer).to receive(:new).and_return(serializer)
      allow(serializer).to receive(:serialized_csv).and_return("sid\n1000000000\n")
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

    it 'serializes within TimeMachine.now' do
      allow(serializer).to receive(:serialized_csv) do
        raise GoodsNomenclatures::NestedSet::DateNotSet unless TimeMachine.date_is_set?

        "sid\n1000000000\n"
      end

      expect { described_class.generate }.not_to raise_error
    end
  end
end
