RSpec.describe 'Internal image descriptions', :internal do
  let(:path) { '/uk/internal/image_descriptions' }
  let(:bytes) { Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j3ioAAAAASUVORK5CYII=') }
  let(:upload) { Rack::Test::UploadedFile.new(StringIO.new(bytes), 'image/png', true, original_filename: 'product.png') }

  let(:directory) { Pathname(Dir.mktmpdir('image-description-spec')) }

  before do
    allow(ImageDescription).to receive(:root).and_return(directory)
    allow(Rails.configuration.action_controller).to receive(:perform_caching).and_return(true)
  end

  after do
    ImageDescriptionWorker.jobs.each { |job| ImageDescription.new(job['args'].first).delete }
    FileUtils.remove_entry(directory)
  end

  it 'queues an id, not image bytes' do
    post path, params: { image: upload, request_id: 'image-journey' }, headers: { 'User-Agent' => 'TradeTariffFrontend/test' }

    expect(response).to have_http_status(:accepted)
    id = response.parsed_body.fetch('id')
    job = ImageDescription.new(id)
    expect(ImageDescriptionWorker.jobs.last['args']).to eq([id])
    expect(job.payload).to include('status' => 'queued', 'request_id' => 'image-journey')
    expect(job.payload.to_json).not_to include(Base64.strict_encode64(bytes))
    expect(File.binread(job.input_path)).to eq(bytes)
    expect(File.stat(job.input_path).mode & 0o777).to eq(0o600)
    expect(Sidekiq.redis { |redis| redis.ttl(job.key) }).to be_between(1, 600)
    expect(response.headers['Cache-Control']).to eq('no-store')
  end

  it 'returns the editable description' do
    post path, params: { image: upload }
    job = ImageDescription.new(response.parsed_body.fetch('id'))
    expect(job.claim).to include('status' => 'running')
    expect(job.claim).to be_nil
    job.complete('description' => 'A red apple.', 'uncertainties' => [])
    job.fail('Late failure')

    get "#{path}/#{job.id}"

    expect(response.parsed_body).to eq('id' => job.id, 'status' => 'completed', 'description' => 'A red apple.', 'uncertainties' => [])
  end

  it 'does not accept paths or URLs' do
    post path, params: { image: 'http://169.254.169.254/latest/meta-data/' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Choose an image file.' }])
    expect(ImageDescriptionWorker.jobs).to be_empty
  end

  it 'rejects a disguised SVG' do
    file = Rack::Test::UploadedFile.new(StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"></svg>'), 'image/png', true, original_filename: 'product.png')
    post path, params: { image: file }

    expect(response).to have_http_status(:unsupported_media_type)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Choose a JPEG, PNG, WebP, GIF, HEIC, HEIF, AVIF or TIFF image.' }])
  end

  it 'rejects oversized images' do
    stub_const('ImageDescription::MAX_BYTES', bytes.bytesize - 1)
    post path, params: { image: upload }

    expect(response).to have_http_status(:content_too_large)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Choose an image smaller than 15 MB.' }])
  end

  it 'bounds staged work' do
    stub_const('ImageDescription::MAX_PENDING', 1)
    post path, params: { image: upload }
    post path, params: { image: upload }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Image description is busy. Wait a moment and try again.' }])
    expect(ImageDescriptionWorker.jobs.size).to eq(1)
  end

  it 'removes a rejected enqueue' do
    allow(ImageDescriptionWorker).to receive(:perform_async).and_return(nil)
    post path, params: { image: upload }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Image description is temporarily unavailable. Try again or type a description.' }])
    expect(ImageDescription.root.children.select(&:directory?)).to be_empty
  end

  it 'serializes Redis failures for uploads and polling' do
    allow(Sidekiq).to receive(:redis).and_raise(RedisClient::ConnectionError, 'private connection details')

    post path, params: { image: upload }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Image description is temporarily unavailable. Try again or type a description.' }])
    expect(ImageDescription.root.children.select(&:directory?)).to be_empty

    get "#{path}/#{SecureRandom.uuid}"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Image description is temporarily unavailable. Try again or type a description.' }])
  end

  it 'cleans staged images when enqueueing raises a Redis error' do
    allow(ImageDescriptionWorker).to receive(:perform_async).and_raise(RedisClient::ConnectionError, 'private connection details')

    post path, params: { image: upload }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('errors' => [{ 'detail' => 'Image description is temporarily unavailable. Try again or type a description.' }])
    expect(ImageDescription.root.children.select(&:directory?)).to be_empty
  end

  it 'does not recreate expired jobs' do
    post path, params: { image: upload }
    job = ImageDescription.new(response.parsed_body.fetch('id'))
    job.claim
    job.delete
    job.complete('description' => 'Late', 'uncertainties' => [])
    get "#{path}/#{job.id}"

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects malformed ids' do
    get "#{path}/not-a-job"

    expect(response).to have_http_status(:not_found)
  end

  it 'accepts uploads without a backend feature flag' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('IMAGE_DESCRIPTIONS_ENABLED').and_return(nil)
    post path, params: { image: upload }

    expect(response).to have_http_status(:accepted)
  end

  it 'accepts uploads in production' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production'))
    post path, params: { image: upload }

    expect(response).to have_http_status(:accepted)
  end

  it 'accepts nonlocal internal uploads and polling' do
    headers = { 'REMOTE_ADDR' => '203.0.113.1', 'User-Agent' => 'TradeTariffFrontend/test' }
    post path, params: { image: upload }, headers: headers

    expect(response).to have_http_status(:accepted)
    id = response.parsed_body.fetch('id')

    get "#{path}/#{id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('id' => id, 'status' => 'queued')
    expect(response.headers['Cache-Control']).to eq('no-store')
  end
end
