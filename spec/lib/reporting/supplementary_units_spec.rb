RSpec.describe Reporting::SupplementaryUnits do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(described_class).to receive(:rows).and_return([
        %w[0101210000 1 109 KGM X uk],
      ])
    end

    it 'writes a CSV file to the reporting bucket' do
      described_class.generate

      expect(s3_bucket.client.api_requests).to include(
        hash_including(
          operation_name: :put_object,
          params: hash_including(
            bucket: s3_bucket.name,
            key: /^.*\/supplementary_units_.*\.csv$/,
            body: a_string_including('goods_nomenclature_item_id', '0101210000'),
            content_type: 'text/csv',
          ),
        ),
      )
    end
  end
end
