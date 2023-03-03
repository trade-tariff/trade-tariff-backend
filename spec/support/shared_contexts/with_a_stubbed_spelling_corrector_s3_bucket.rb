RSpec.shared_context 'with a stubbed spelling corrector bucket' do
  before do
    s3_bucket.client.stub_responses(:get_object, get_object_handler)
    s3_bucket.client.stub_responses(:list_objects_v2, list_objects_v2_handler)
    s3_bucket.client.stub_responses(:put_object)
  end

  let(:get_object_handler) do
    lambda do |context|
      case context.params[:key]
      when 'spelling-corrector/initial-spelling-model.txt'
        { body: StringIO.new(file_fixture('spelling_corrector/initial-spelling-model.txt').read) }
      when 'spelling-corrector/origin-reference/foo.txt'
        { body: StringIO.new(file_fixture('spelling_corrector/origin_reference/foo.txt').read) }
      when 'spelling-corrector/origin-reference/bar.txt'
        { body: StringIO.new(file_fixture('spelling_corrector/origin_reference/bar.txt').read) }
      when 'config/chief_cds_guidance.json'
        { body: StringIO.new(file_fixture('chief_cds_guidance.json').read) }
      end
    end
  end

  let(:list_objects_v2_handler) do
    lambda do |context|
      case context.params[:prefix]
      when 'spelling-corrector/origin-reference/'
        {
          contents: [
            { key: 'spelling-corrector/origin-reference/foo.txt' },
            { key: 'spelling-corrector/origin-reference/bar.txt' },
          ],
        }
      end
    end
  end

  let(:s3_bucket) do
    Rails
      .application
      .config
      .spelling_corrector_s3_bucket
  end
end
