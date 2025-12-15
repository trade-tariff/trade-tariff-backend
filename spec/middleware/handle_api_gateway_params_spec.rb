RSpec.describe HandleApiGatewayParams do
  subject(:query_string) do
    _, updated_env, _response = middleware.call(env)
    CGI.unescape(Rack::Request.new(updated_env).query_string)
  end

  let(:middleware) { described_class.new(app) }

  let(:app) { ->(env) { [200, env, %w[OK]] } }
  let(:env) { Rack::MockRequest.env_for(path) }

  describe '#call' do
    context 'when there are deeply nested dot-separated query params in the path' do
      let(:path) { '/uk/api/commodities/0100000000?as_of=2025-11-01&filter.geographical_area_id=GB&filter.type.foo.bar.baz=qux' }

      it { is_expected.to eq('as_of=2025-11-01&filter[geographical_area_id]=GB&filter[type][foo][bar][baz]=qux') }
    end

    context 'when there are no deeply nested dot-separated query params in the path' do
      let(:path) { '/uk/api/commodities/0100000000?as_of=2025-11-01' }

      it { is_expected.to eq('as_of=2025-11-01') }
    end

    context 'when there are no query params in the path' do
      let(:path) { '/uk/api/commodities/0100000000' }

      it { is_expected.to eq('') }
    end

    context 'when there are malformed dot-separated query params in the path' do
      let(:path) { '/uk/api/commodities/0100000000?filter..geographical_area_id=GB&filter.type..foo=bar' }

      it { is_expected.to eq('filter[][geographical_area_id]=GB&filter[type][][foo]=bar') }
    end

    context 'when path parameters include dots but no query parameters' do
      let(:path) { '/uk/api/some.resource/0100000000.csv' }

      it { is_expected.to eq('') }

      it 'does not modify the path' do
        _, updated_env, _response = middleware.call(env)
        expect(Rack::Request.new(updated_env).path).to eq('/uk/api/some.resource/0100000000.csv')
      end
    end
  end
end
