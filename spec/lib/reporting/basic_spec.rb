RSpec.describe Reporting::Basic, skip: 'pending an investigation' do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    context 'when there are declarable goods nomenclatures' do
      let(:body) { s3_bucket.client.api_requests.first.dig(:params, :body).split("\n") }
      let(:headers) { body.first.split(',') }
      let(:rows) { body.drop(1) }

      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

        create(
          :commodity,
          :with_description,
          description: 'Live horses, asses, mules and hinnies',
          goods_nomenclature_item_id: '0100000002',
        )
        described_class.generate
      end

      it 'writes a CSV file to the reporting bucket' do
        expect(s3_bucket.client.api_requests).to include(
          hash_including(
            operation_name: :put_object,
            params: hash_including(
              bucket: s3_bucket.name,
              key: /^.*\/tariff_data_basic_.*\.csv$/,
              body: instance_of(String),
              content_type: 'text/csv',
            ),
          ),
        )
      end

      it 'writes the correct headers' do
        expect(headers).to eq(
          [
            'Commodity code',
            'Description',
            'Third country duty',
            'Supplementary unit',
          ],
        )
      end

      it 'writes the correct rows' do
        expect(rows).to eq(
          ['0100000002,"Live horses, asses, mules and hinnies",See measure conditions,'],
        )
      end
    end

    context 'when there are no declarable goods nomenclatures' do
      it 'does not write a CSV file to the reporting bucket' do
        expect(s3_bucket.client.api_requests).to be_empty
      end
    end
  end
end
