RSpec.describe Reporting::GeographicalAreaGroups do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    let(:body) { s3_bucket.client.api_requests.first.dig(:params, :body).split("\n") }
    let(:headers) { body.first.split(',') }
    let(:rows) { body.drop(1) }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      create(:geographical_area, :group, :with_description, :with_members)

      described_class.generate
    end

    it 'writes an XLSX file to the reporting bucket' do
      expect(s3_bucket.client.api_requests).to include(
        hash_including(
          operation_name: :put_object,
          params: hash_including(
            bucket: s3_bucket.name,
            key: /^uk\/reporting\/\d{4}\/\d{2}\/\d{2}\/geographical_area_groups_uk_\d{4}_\d{2}_\d{2}\.xlsx$/,
            body: instance_of(String),
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      )
    end
  end
end
