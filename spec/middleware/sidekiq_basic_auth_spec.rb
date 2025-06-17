class MockRackApp
  attr_reader :request_body

  def initialize
    @request_headers = {}
  end

  def call(env)
    @env = env
    [200, { 'Content-Type' => 'text/plain' }, %w[OK]]
  end

  delegate :[], to: :@env
end

RSpec.describe SidekiqBasicAuth do
  subject(:middleware) do
    described_class.new(app) do |username, password|
      username == 'test' && password == 'test'
    end
  end

  let(:app) { MockRackApp.new }
  let(:request) { Rack::MockRequest.new(middleware) }

  context 'when basic auth is active for the current path' do
    let(:path) { '/xi/sidekiq/foo/bar/baz' }
    let(:credentials) { "Basic #{['test:test'].pack('m*')}" }

    it 'returns 401 when unauthenticated' do
      response = request.get(path, 'CONTENT_TYPE' => 'text/plain')
      expect(response.status).to eq(401)
    end

    it 'returns 200 when authenticated' do
      response = request.get(path, 'CONTENT_TYPE' => 'text/plain', 'HTTP_AUTHORIZATION' => credentials)
      expect(response.status).to eq(200)
    end
  end

  context 'when basic auth is not active for the path' do
    before do
      request.get('/foo/1', 'CONTENT_TYPE' => 'text/plain')
    end

    it 'returns 200' do
      response = request.get('/foo/1', 'CONTENT_TYPE' => 'text/plain')
      expect(response.status).to eq(200)
    end
  end
end
