RSpec.describe Reporting::Prohibitions do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'
    let(:body) { s3_bucket.client.api_requests.first.dig(:params, :body).split("\n") }
    let(:headers) { body.first.split(',') }
    let(:rows) { body.drop(1) }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      declarable = create(
        :commodity,
        :with_description,
        description: 'Live horses, asses, mules and hinnies',
        goods_nomenclature_item_id: '0100000002',
      )

      create(
        :measure,
        :with_measure_components,
        :with_additional_code,
        :with_quota_definition,
        :with_measure_conditions,
        :with_footnote_association,
        :with_measure_type,
        measure_type_series_id: 'A',
        goods_nomenclature_sid: declarable.goods_nomenclature_sid,
        goods_nomenclature_item_id: declarable.goods_nomenclature_item_id,
      )

      described_class.generate
    end

    it 'writes an XLSX file to the reporting bucket' do
      expect(s3_bucket.client.api_requests).to include(
        hash_including(
          operation_name: :put_object,
          params: hash_including(
            bucket: s3_bucket.name,
            key: /^uk\/reporting\/\d{4}\/\d{2}\/\d{2}\/declarable_commodities_with_prohibition_measures_uk_\d{4}_\d{2}_\d{2}\.xlsx$/,
            body: instance_of(String),
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      )
    end
  end
end
