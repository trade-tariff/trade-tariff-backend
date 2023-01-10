RSpec.shared_context 'with a stubbed s3 bucket' do
  before do
    stubbed_initial_model_file = StringIO.new(file_fixture('spelling_corrector/initial-spelling-model.txt').read)

    s3_bucket.client.stub_responses(:get_object, { body: stubbed_initial_model_file })
    s3_bucket.client.stub_responses(:put_object)
  end

  let(:s3_bucket) do
    Rails
      .application
      .config
      .spelling_corrector_s3_bucket
  end
end
