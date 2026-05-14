# frozen_string_literal: true

RSpec.describe UseReaderForReads do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(env) { [200, env, %w[OK]] } }

  before do
    allow(Sequel::Model.db).to receive(:with_server).and_yield
  end

  describe '#call' do
    context 'when the request method is GET' do
      let(:env) { Rack::MockRequest.env_for('/uk/api/commodities', method: 'GET') }

      it 'routes through the reader server' do
        middleware.call(env)
        expect(Sequel::Model.db).to have_received(:with_server).with(:reader)
      end

      it 'calls the inner app' do
        status, = middleware.call(env)
        expect(status).to eq(200)
      end
    end

    context 'when the request method is HEAD' do
      let(:env) { Rack::MockRequest.env_for('/uk/api/commodities', method: 'HEAD') }

      it 'routes through the reader server' do
        middleware.call(env)
        expect(Sequel::Model.db).to have_received(:with_server).with(:reader)
      end

      it 'calls the inner app' do
        status, = middleware.call(env)
        expect(status).to eq(200)
      end
    end

    context 'when the GET request is under the user API' do
      let(:env) { Rack::MockRequest.env_for('/uk/user/commodity_changes', method: 'GET') }

      it 'does not route through the reader server' do
        middleware.call(env)
        expect(Sequel::Model.db).not_to have_received(:with_server)
      end
    end

    context 'when the HEAD request is under the user API' do
      let(:env) { Rack::MockRequest.env_for('/uk/user/users', method: 'HEAD') }

      it 'does not route through the reader server' do
        middleware.call(env)
        expect(Sequel::Model.db).not_to have_received(:with_server)
      end
    end

    context 'when the request method is POST' do
      let(:env) { Rack::MockRequest.env_for('/uk/api/something', method: 'POST') }

      it 'does not route through the read_only server' do
        middleware.call(env)
        expect(Sequel::Model.db).not_to have_received(:with_server)
      end

      it 'calls the inner app' do
        status, = middleware.call(env)
        expect(status).to eq(200)
      end
    end

    context 'when the request method is PUT' do
      let(:env) { Rack::MockRequest.env_for('/uk/api/something', method: 'PUT') }

      it 'does not route through the read_only server' do
        middleware.call(env)
        expect(Sequel::Model.db).not_to have_received(:with_server)
      end
    end

    context 'when the request method is DELETE' do
      let(:env) { Rack::MockRequest.env_for('/uk/api/something', method: 'DELETE') }

      it 'does not route through the read_only server' do
        middleware.call(env)
        expect(Sequel::Model.db).not_to have_received(:with_server)
      end
    end

    context 'when the request method is PATCH' do
      let(:env) { Rack::MockRequest.env_for('/uk/api/something', method: 'PATCH') }

      it 'does not route through the read_only server' do
        middleware.call(env)
        expect(Sequel::Model.db).not_to have_received(:with_server)
      end
    end
  end
end
