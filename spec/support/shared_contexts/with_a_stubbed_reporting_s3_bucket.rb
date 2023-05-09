RSpec.shared_context 'with a stubbed reporting bucket' do
  before do
    s3_bucket.client.setup_stubbing
    s3_bucket.client.stub_responses(:put_object)
  end

  let(:s3_bucket) do
    Rails
      .application
      .config
      .reporting_bucket
  end
end
