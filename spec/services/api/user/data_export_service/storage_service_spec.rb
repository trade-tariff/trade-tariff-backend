RSpec.describe Api::User::DataExportService::StorageService do
  subject(:service) { described_class.new(bucket_name: bucket_name, region: region) }

  let(:bucket_name) { 'test-bucket' }
  let(:region) { 'eu-west-2' }
  let(:key) { 'path/file.xlsx' }
  let(:content_type) { 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }

  let(:s3_resource) { instance_double(Aws::S3::Resource) }
  let(:bucket) { instance_double(Aws::S3::Bucket) }
  let(:object) { instance_double(Aws::S3::Object) }

  before do
    allow(Aws::S3::Resource).to receive(:new).with(region: region).and_return(s3_resource)
    allow(s3_resource).to receive(:bucket).with(bucket_name).and_return(bucket)
    allow(bucket).to receive(:object).and_return(object)
  end

  describe 'production mode' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    end

    describe '#upload' do
      it 'uploads bytes with content type to s3' do
        allow(object).to receive(:put)

        service.upload(
          key: key,
          body: 'bytes',
          content_type: content_type,
        )

        expect(bucket).to have_received(:object).with(key)
        expect(object).to have_received(:put).with(
          body: 'bytes',
          content_type: content_type,
        )
      end
    end

    describe '#download' do
      it 'downloads bytes from s3' do
        body = instance_double(StringIO, read: 'file-bytes')
        response = instance_double(Aws::S3::Types::GetObjectOutput, body: body)
        allow(object).to receive(:get).and_return(response)

        expect(service.download(key: key)).to eq('file-bytes')
      end
    end

    describe '#presigned_get_url' do
      it 'returns a presigned s3 url' do
        allow(object).to receive(:presigned_url).with(:get, expires_in: 300).and_return('https://example.com/presigned')

        expect(service.presigned_get_url(key: key)).to eq('https://example.com/presigned')
      end
    end
  end
end
