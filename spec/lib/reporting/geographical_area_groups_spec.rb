RSpec.describe Reporting::GeographicalAreaGroups do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      create(:geographical_area, :group, :with_description, :with_members)
    end

    context 'when generation succeeds' do
      before { described_class.generate }

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

    context 'when upload fails' do
      let(:logger) { instance_double(Logger, info: nil, error: nil, debug: nil) }
      let(:error) { StandardError.new('upload failed') }
      let(:s3_object) { instance_double(Aws::S3::Object, put: nil) }

      before do
        allow(Rails).to receive(:logger).and_return(logger)
        allow(described_class).to receive(:object).and_return(s3_object)
        allow(s3_object).to receive(:put).and_raise(error)
      end

      it 'logs the failing step and re-raises the error' do
        expect { described_class.generate }.to raise_error(error.class, 'upload failed')

        expect(logger).to have_received(:info).with(
          a_string_including(
            'reporting',
            'report="Reporting::GeographicalAreaGroups"',
            'step="upload"',
            'status="error"',
            'error_class="StandardError"',
            'error_message="upload failed"',
          ),
        )
      end
    end
  end
end
