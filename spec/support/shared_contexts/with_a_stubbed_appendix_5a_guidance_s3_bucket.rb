RSpec.shared_context 'with a stubbed appendix 5a guidance s3 bucket' do
  before do
    s3_bucket.client.stub_responses(:get_object, get_object_handler)
  end

  let(:get_object_handler) do
    lambda do |context|
      case context.params[:key]
      when 'config/cds_guidance.json'
        { body: StringIO.new(file_fixture('appendix_5a_guidance.json').read) }
      end
    end
  end

  let(:s3_bucket) do
    Rails
      .application
      .config
      .persistence_bucket
  end
end
